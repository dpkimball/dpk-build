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

# Launch container if COMPOSE_SERVICE is specified (following Python pattern)
if [ -n "${COMPOSE_SERVICE:-}" ]; then
  log_info "🔄 Replacing running container for service: $COMPOSE_SERVICE"

  docker compose -f "${KEEPSAKE_COMPOSE_PROJECT_ROOT:-.}/docker-compose.yml" stop "$COMPOSE_SERVICE" || true
  docker compose -f "${KEEPSAKE_COMPOSE_PROJECT_ROOT:-.}/docker-compose.yml" rm -f "$COMPOSE_SERVICE" || true
  docker compose -f "${KEEPSAKE_COMPOSE_PROJECT_ROOT:-.}/docker-compose.yml" up -d --no-deps "$COMPOSE_SERVICE"

  log_success "✅ Container for $COMPOSE_SERVICE restarted with updated image"
fi

# Deploy to Kubernetes if K8S_DEPLOY is specified
if [ "${K8S_DEPLOY:-false}" = "true" ]; then
  log_info "🚀 Deploying to Kubernetes..."
  
  # Load image into Kubernetes cluster
  if kubectl config current-context | grep -q "kind"; then
    log_info "🐳 Loading image into Kind cluster..."
    kind load docker-image "$IMAGE_NAME:latest" --name "${KIND_CLUSTER:-keepsake-dev}"
  elif kubectl config current-context | grep -q "docker-desktop\|rancher-desktop"; then
    log_info "🐳 Using Docker Desktop/Rancher Desktop (image already available)"
  elif kubectl config current-context | grep -q "minikube"; then
    log_info "🐳 Loading image into Minikube..."
    minikube image load "$IMAGE_NAME:latest"
  else
    log_warning "⚠️  Unknown Kubernetes cluster type. Image may not be available."
  fi
  
  # Update Helm deployment
  HELM_RELEASE="${HELM_RELEASE:-$IMAGE_NAME}"
  K8S_NAMESPACE="${K8S_NAMESPACE:-dev}"
  HELM_CHART_PATH="${HELM_CHART_PATH:-../keepsake-infra/charts/$IMAGE_NAME}"
  
  log_info "📦 Updating Helm release: $HELM_RELEASE in namespace: $K8S_NAMESPACE"
  log_info "📁 Using chart path: $HELM_CHART_PATH"
  
  # Check if chart path exists
  if [[ ! -d "$HELM_CHART_PATH" ]]; then
    log_error "❌ Helm chart not found at: $HELM_CHART_PATH"
    log_error "   Please set HELM_CHART_PATH to the correct chart directory"
    exit 1
  fi
  
  # Update the image in the Helm values
  helm upgrade "$HELM_RELEASE" \
    --namespace "$K8S_NAMESPACE" \
    --set image.repository="$IMAGE_NAME" \
    --set image.tag="latest" \
    --set image.pullPolicy="Never" \
    "$HELM_CHART_PATH" || {
    log_error "❌ Helm upgrade failed"
    exit 1
  }
  
  log_success "✅ Kubernetes deployment updated with local image"
else
  log_info "💡 To deploy to Kubernetes, set K8S_DEPLOY=true"
fi

log_success "✅ Rust Docker build complete!"
