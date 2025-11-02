#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ -f .env.build ] && source .env.build

IMAGE_NAME="${IMAGE_NAME:-my_image}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
COMPOSE_SERVICE="${COMPOSE_SERVICE:-}"
SKIP_TESTS="${SKIP_TESTS:-true}"
CLEAN="${CLEAN:-false}"
CLEANUP_OLD_IMAGES="${CLEANUP_OLD_IMAGES:-true}"

print_status "🔍 Config: IMAGE_NAME=$IMAGE_NAME | CLEAN=$CLEAN | SKIP_TESTS=$SKIP_TESTS | COMPOSE_SERVICE=$COMPOSE_SERVICE"

if [ "$CLEAN" = true ]; then
  print_status "🧼 Cleaning previous Docker artifacts..."
  docker stop "$IMAGE_NAME" || true
  docker rm "$IMAGE_NAME" || true
  docker image rm "$IMAGE_NAME:latest" || true
fi

# Aggressive cleanup of all old images if requested
if [ "${CLEANUP_ALL_OLD_IMAGES:-false}" = true ]; then
  print_status "🧹 Aggressive cleanup: Removing all old Docker images..."
  # Remove all images except the ones we just built
  docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep -v "REPOSITORY" | grep -v "$IMAGE_NAME:latest" | grep -v "$IMAGE_NAME:$DATE_TAG" | awk '{print $1}' | xargs -r docker rmi || true
  print_status "✅ All old images cleaned up"
fi

print_status "🐳 Building Docker image..."
DATE_TAG=$(date +"%Y%m%d-%H%M")

# Build command with optional build arguments
BUILD_CMD="docker build --network host"

# Add build arguments if environment variables are set
# Prefer container-safe URL for builds, fall back to generic
_UV_URL_FOR_BUILD="${UV_INDEX_URL_BUILD:-${UV_INDEX_URL:-}}"
if [ -n "${_UV_URL_FOR_BUILD}" ]; then
    BUILD_CMD="$BUILD_CMD --build-arg UV_INDEX_URL=\"$_UV_URL_FOR_BUILD\""
fi
if [ -n "${UV_EXTRA_INDEX_URL:-}" ]; then
    BUILD_CMD="$BUILD_CMD --build-arg UV_EXTRA_INDEX_URL=\"$UV_EXTRA_INDEX_URL\""
fi
if [ -n "${PIP_INDEX_URL:-}" ]; then
    BUILD_CMD="$BUILD_CMD --build-arg PIP_INDEX_URL=\"$PIP_INDEX_URL\""
fi
if [ -n "${PIP_EXTRA_INDEX_URL:-}" ]; then
    BUILD_CMD="$BUILD_CMD --build-arg PIP_EXTRA_INDEX_URL=\"$PIP_EXTRA_INDEX_URL\""
fi
if [ -n "${CACHE_BUST:-}" ]; then
    BUILD_CMD="$BUILD_CMD --build-arg CACHE_BUST=\"$CACHE_BUST\""
fi
if [ -n "${VITE_API_URL:-}" ]; then
    BUILD_CMD="$BUILD_CMD --build-arg VITE_API_URL=\"$VITE_API_URL\""
fi
if [ -n "${VITE_MEDIA_BASE_URL:-}" ]; then
    BUILD_CMD="$BUILD_CMD --build-arg VITE_MEDIA_BASE_URL=\"$VITE_MEDIA_BASE_URL\""
fi

# Add tags and build context
BUILD_CMD="$BUILD_CMD -t \"$IMAGE_NAME:latest\" -t \"$IMAGE_NAME:$DATE_TAG\" \"$DOCKERFILE_DIR\""

# Execute the build command
eval $BUILD_CMD

print_status "✅ Build complete. Tagged as $DATE_TAG"

# Clean up old images to save disk space
if [ "$CLEANUP_OLD_IMAGES" = true ]; then
  print_status "🧹 Cleaning up old Docker images..."
  # Remove all old versions of this image, keeping only 'latest' and the current DATE_TAG
  docker images "$IMAGE_NAME" --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep -v "latest" | grep -v "$DATE_TAG" | awk '{print $1}' | xargs -r docker rmi || true
  print_status "✅ Old images cleaned up"
fi

if [ "$SKIP_TESTS" != true ]; then
  if [ -f "./test.sh" ]; then
    ./test.sh || print_warning "⚠ Tests failed"
  else
    print_warning "⚠ No test.sh found, skipping tests"
  fi
fi

# Deploy to Kubernetes if K8S_DEPLOY is specified (backward compatibility)
if [ "${K8S_DEPLOY:-false}" = "true" ]; then
  "$KEEPSAKE_SCRIPTS_ROOT/deploy-k8s.sh"
elif [ -n "$COMPOSE_SERVICE" ]; then
  print_status "🔄 Replacing running container for service: $COMPOSE_SERVICE"

  docker compose -f "$KEEPSAKE_COMPOSE_PROJECT_ROOT/docker-compose.yml" stop "$COMPOSE_SERVICE" || true
  docker compose -f "$KEEPSAKE_COMPOSE_PROJECT_ROOT/docker-compose.yml" rm -f "$COMPOSE_SERVICE" || true
  docker compose -f "$KEEPSAKE_COMPOSE_PROJECT_ROOT/docker-compose.yml" up -d --no-deps "$COMPOSE_SERVICE"

  print_status "✅ Container for $COMPOSE_SERVICE restarted with updated image"
else
  print_warning "⚠ No COMPOSE_SERVICE or K8S_DEPLOY specified, skipping container restart"
fi