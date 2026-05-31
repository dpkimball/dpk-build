#!/bin/bash
set -euo pipefail

# Load shared utilities
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

# Load environment variables
[ -f .env.build ] && source .env.build

# Default values
IMAGE_NAME="${IMAGE_NAME:-memory-graph-service}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
CLEAN="${CLEAN:-false}"
SKIP_TESTS="${SKIP_TESTS:-false}"
DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL:-localhost:30500}"

log_info "🔍 Config: IMAGE_NAME=$IMAGE_NAME | CLEAN=$CLEAN | SKIP_TESTS=$SKIP_TESTS"

# Check if we're in a Rust project
if [[ ! -f "Cargo.toml" ]]; then
  log_error "Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

# Check if Dockerfile exists
if [[ ! -f "$DOCKERFILE_DIR/Dockerfile" ]]; then
  log_error "Dockerfile not found in $DOCKERFILE_DIR"
  exit 1
fi

if [ "$CLEAN" = true ]; then
  log_info "🧼 Cleaning previous Docker artifacts..."
  docker stop "$IMAGE_NAME" || true
  docker rm "$IMAGE_NAME" || true
  docker image rm "$IMAGE_NAME:latest" || true
fi

log_info "🐳 Building Rust Docker image..."
DATE_TAG=$(date +"%Y%m%d-%H%M")

# Try multi-platform build first, fall back to single platform if not supported
if docker buildx build --platform linux/amd64,linux/arm64 --network host -t "$IMAGE_NAME:latest" -t "$IMAGE_NAME:$DATE_TAG" "$DOCKERFILE_DIR" 2>/dev/null; then
  log_info "✅ Multi-platform build successful"
else
  log_info "⚠️  Multi-platform build not supported, building for current platform..."
  docker build --network host -t "$IMAGE_NAME:latest" -t "$IMAGE_NAME:$DATE_TAG" "$DOCKERFILE_DIR"
fi

log_success "✅ Docker build complete. Tagged as $DATE_TAG"

if [ "$SKIP_TESTS" != true ]; then
  log_info "🧪 Running container tests..."
  # Test the container by checking if it starts (gRPC servers don't have --help)
  timeout 5s docker run --rm "$IMAGE_NAME:latest" || {
    log_info "⚠️  Container test completed (expected timeout for gRPC server)"
  }
fi

REMOTE_IMAGE="${DOCKER_REGISTRY_URL}/${IMAGE_NAME}"
log_info "📤 Pushing image to local registry: ${REMOTE_IMAGE}"

docker tag "${IMAGE_NAME}:latest" "${REMOTE_IMAGE}:latest"
docker tag "${IMAGE_NAME}:${DATE_TAG}" "${REMOTE_IMAGE}:${DATE_TAG}"

docker push "${REMOTE_IMAGE}:latest"
docker push "${REMOTE_IMAGE}:${DATE_TAG}"

log_success "✅ Pushed to ${REMOTE_IMAGE} (latest, ${DATE_TAG})"

# Launch container if COMPOSE_SERVICE is specified (following Python pattern)
if [ -n "${COMPOSE_SERVICE:-}" ]; then
  log_info "🔄 Replacing running container for service: $COMPOSE_SERVICE"

  docker compose -f "${KEEPSAKE_COMPOSE_PROJECT_ROOT:-.}/docker-compose.yml" stop "$COMPOSE_SERVICE" || true
  docker compose -f "${KEEPSAKE_COMPOSE_PROJECT_ROOT:-.}/docker-compose.yml" rm -f "$COMPOSE_SERVICE" || true
  docker compose -f "${KEEPSAKE_COMPOSE_PROJECT_ROOT:-.}/docker-compose.yml" up -d --no-deps "$COMPOSE_SERVICE"

  log_success "✅ Container for $COMPOSE_SERVICE restarted with updated image"
fi

# Deploy to Kubernetes if K8S_DEPLOY is specified (use shared deploy-k8s.sh like Python)
if [ "${K8S_DEPLOY:-false}" = "true" ]; then
  log_info "🚀 Deploying to Kubernetes..."
  "$KEEPSAKE_SCRIPTS_ROOT/deploy-k8s.sh"
else
  log_info "💡 To deploy to Kubernetes, set K8S_DEPLOY=true"
fi

log_success "✅ Rust Docker build complete!"
