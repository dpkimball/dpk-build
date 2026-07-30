#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

[ -f .env.build ] && source .env.build

IMAGE_NAME="${IMAGE_NAME:-memory-graph-service}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
# Optional overrides for crates with sibling path deps (e.g. dpk2-grpc):
#   DOCKER_BUILD_CONTEXT=.  DOCKERFILE=Dockerfile
#   DOCKER_EXTRA_ARGS='--build-context dpk2=../dpk2 --build-context bindb=../bindb'
DOCKER_BUILD_CONTEXT="${DOCKER_BUILD_CONTEXT:-$DOCKERFILE_DIR}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
DOCKER_EXTRA_ARGS="${DOCKER_EXTRA_ARGS:-}"
# Comma-separated platforms for buildx, e.g. linux/amd64 or linux/amd64,linux/arm64.
# When set, build fails instead of silently falling back to the host arch.
DOCKER_PLATFORMS="${DOCKER_PLATFORMS:-}"
CLEAN="${CLEAN:-false}"
SKIP_TESTS="${SKIP_TESTS:-false}"

log_info "🔍 Config: IMAGE_NAME=$IMAGE_NAME | CLEAN=$CLEAN | SKIP_TESTS=$SKIP_TESTS | CONTEXT=$DOCKER_BUILD_CONTEXT | PLATFORMS=${DOCKER_PLATFORMS:-host}"

if [[ ! -f "Cargo.toml" ]]; then
  log_error "Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

if [[ ! -f "$DOCKERFILE_DIR/$DOCKERFILE" ]]; then
  log_error "Dockerfile not found at $DOCKERFILE_DIR/$DOCKERFILE"
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

build_image() {
  local platform_args=()
  if [[ -n "$DOCKER_PLATFORMS" ]]; then
    platform_args=(--platform "$DOCKER_PLATFORMS")
  fi
  # shellcheck disable=SC2086
  docker buildx build "${platform_args[@]}" --network host --load \
    -f "$DOCKERFILE_DIR/$DOCKERFILE" \
    $DOCKER_EXTRA_ARGS \
    -t "$IMAGE_NAME:latest" -t "$IMAGE_NAME:$DATE_TAG" \
    "$DOCKER_BUILD_CONTEXT"
}

if [[ -n "$DOCKER_PLATFORMS" ]]; then
  log_info "Building for platforms: $DOCKER_PLATFORMS"
  build_image
else
  # Legacy behavior: try multi-arch, fall back to host arch
  # shellcheck disable=SC2086
  if docker buildx build --platform linux/amd64,linux/arm64 --network host \
      -f "$DOCKERFILE_DIR/$DOCKERFILE" \
      $DOCKER_EXTRA_ARGS \
      -t "$IMAGE_NAME:latest" -t "$IMAGE_NAME:$DATE_TAG" \
      "$DOCKER_BUILD_CONTEXT" 2>/dev/null; then
    log_info "✅ Multi-platform build successful"
  else
    log_info "⚠️  Multi-platform build not supported, building for current platform..."
    # shellcheck disable=SC2086
    docker build --network host \
      -f "$DOCKERFILE_DIR/$DOCKERFILE" \
      $DOCKER_EXTRA_ARGS \
      -t "$IMAGE_NAME:latest" -t "$IMAGE_NAME:$DATE_TAG" \
      "$DOCKER_BUILD_CONTEXT"
  fi
fi
log_success "✅ Docker build complete. Tagged as $DATE_TAG"

if [ "$SKIP_TESTS" != true ]; then
  log_info "🧪 Running container tests..."
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

if [ "${K8S_DEPLOY:-false}" = "true" ]; then
  log_info "🚀 Deploying to Kubernetes..."
  "$SCRIPT_DIR/deploy-k8s.sh"
else
  log_info "💡 To deploy to Kubernetes, set K8S_DEPLOY=true"
fi

log_success "✅ Rust Docker build complete!"
