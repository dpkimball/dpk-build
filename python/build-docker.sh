#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

[ -f .env.build ] && source .env.build

IMAGE_NAME="${IMAGE_NAME:-my_image}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
CLEAN="${CLEAN:-false}"
# Always cleanup old images - this is not optional
CLEANUP_OLD_IMAGES="${CLEANUP_OLD_IMAGES:-true}"

print_status "🔍 Config: IMAGE_NAME=$IMAGE_NAME | CLEAN=$CLEAN"

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

# Clean up old images BEFORE building to free space (critical to prevent disk fill)
print_status "🧹 Pre-build cleanup: Removing old images to free space..."
REGISTRY_URL="${DOCKER_REGISTRY_URL}"

if [ "$CLEANUP_OLD_IMAGES" = true ]; then
  # Remove ALL old date-tagged images for this repository (keep only the most recent one if any)
  # This prevents accumulation when builds fail or are interrupted
  OLD_DATE_TAGS=$(docker images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | \
    { grep -E "^$IMAGE_NAME:[0-9]{8}-[0-9]{4}$" || true; } | sort -r | tail -n +2)
  if [ -n "$OLD_DATE_TAGS" ]; then
    echo "$OLD_DATE_TAGS" | xargs -r docker rmi -f 2>/dev/null || true
    print_status "✅ Removed old date-tagged images"
  fi
  
  # Remove all orphaned <none> tagged images for this repository
  docker images "$IMAGE_NAME" --format "{{.ID}}\t{{.Tag}}" 2>/dev/null | \
    grep -E "\t<none>" | awk '{print $1}' | \
    xargs -r docker rmi -f 2>/dev/null || true
  
  # Clean up registry images: remove all except latest (including <none> tags)
  docker images "$REGISTRY_URL/$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}\t{{.ID}}" 2>/dev/null | \
    grep -v "REPOSITORY" | grep -v "^$REGISTRY_URL/$IMAGE_NAME:latest" | \
    awk '{print $1}' | xargs -r docker rmi -f 2>/dev/null || true

  docker images "$REGISTRY_URL/$IMAGE_NAME" --format "{{.ID}}\t{{.Tag}}" 2>/dev/null | \
    grep -E "\t<none>" | awk '{print $1}' | \
    xargs -r docker rmi -f 2>/dev/null || true
fi

print_status "🐳 Building Docker image..."
DATE_TAG="${DATE_TAG:-$(date +"%Y%m%d-%H%M")}"

# Debug: Show UV_INDEX_URL_BUILD before build
_UV_URL_FOR_BUILD="${UV_INDEX_URL_BUILD:-${UV_INDEX_URL:-}}"
print_status "🔍 Debug: UV_INDEX_URL_BUILD=${UV_INDEX_URL_BUILD:-not set}"
print_status "🔍 Debug: UV_INDEX_URL=${UV_INDEX_URL:-not set}"
print_status "🔍 Debug: Using for build: ${_UV_URL_FOR_BUILD:-not set}"

BUILD_ARGS=(docker build --network host)
if [ "${DOCKER_BUILD_PULL:-}" = "false" ]; then
    BUILD_ARGS+=(--pull=false)
fi
if [ "$DOCKERFILE" != "Dockerfile" ]; then
    BUILD_ARGS+=(-f "$DOCKERFILE")
fi

if [ -n "${BASE_IMAGE:-}" ]; then
    BUILD_ARGS+=(--build-arg "BASE_IMAGE=$BASE_IMAGE")
fi
if [ -n "${_UV_URL_FOR_BUILD}" ]; then
    BUILD_ARGS+=(--build-arg "UV_INDEX_URL=$_UV_URL_FOR_BUILD")
fi
if [ -n "${UV_EXTRA_INDEX_URL:-}" ]; then
    BUILD_ARGS+=(--build-arg "UV_EXTRA_INDEX_URL=$UV_EXTRA_INDEX_URL")
fi
if [ -n "${PIP_INDEX_URL:-}" ]; then
    BUILD_ARGS+=(--build-arg "PIP_INDEX_URL=$PIP_INDEX_URL")
fi
if [ -n "${PIP_EXTRA_INDEX_URL:-}" ]; then
    BUILD_ARGS+=(--build-arg "PIP_EXTRA_INDEX_URL=$PIP_EXTRA_INDEX_URL")
fi
if [ -n "${CACHE_BUST:-}" ]; then
    BUILD_ARGS+=(--build-arg "CACHE_BUST=$CACHE_BUST")
fi
if [ -n "${VITE_API_URL:-}" ]; then
    BUILD_ARGS+=(--build-arg "VITE_API_URL=$VITE_API_URL")
fi
if [ -n "${VITE_MEDIA_BASE_URL:-}" ]; then
    BUILD_ARGS+=(--build-arg "VITE_MEDIA_BASE_URL=$VITE_MEDIA_BASE_URL")
fi

BUILD_ARGS+=(-t "$IMAGE_NAME:$DATE_TAG" "$DOCKERFILE_DIR")
"${BUILD_ARGS[@]}"

print_status "✅ Build complete. Tagged as $DATE_TAG"

REGISTRY_URL="${DOCKER_REGISTRY_URL}"
print_status "📤 Pushing to local registry at $REGISTRY_URL..."

docker tag "$IMAGE_NAME:$DATE_TAG" "$IMAGE_NAME:latest" || {
  print_error "Failed to tag $IMAGE_NAME:$DATE_TAG as latest"
  exit 1
}

REGISTRY_TAG="$REGISTRY_URL/$IMAGE_NAME:latest"
print_status "🏷️  Tagging as $REGISTRY_TAG..."
docker tag "$IMAGE_NAME:latest" "$REGISTRY_TAG" || {
  print_error "Failed to tag $IMAGE_NAME:latest"
  exit 1
}

print_status "📤 Pushing $REGISTRY_TAG..."
docker push "$REGISTRY_TAG" || {
  print_error "Failed to push $REGISTRY_TAG. Is registry running at $REGISTRY_URL?"
  exit 1
}
print_status "✅ Pushed $REGISTRY_TAG"

print_status "🧹 Post-push cleanup..."

docker rmi "$IMAGE_NAME:latest" 2>/dev/null || true

docker images "$REGISTRY_URL/$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}\t{{.ID}}" 2>/dev/null | \
  grep -v "REPOSITORY" | grep -v "^$REGISTRY_URL/$IMAGE_NAME:latest" | \
  awk '{print $1}' | xargs -r docker rmi -f 2>/dev/null || true

docker images "$REGISTRY_URL/$IMAGE_NAME" --format "{{.ID}}\t{{.Tag}}" 2>/dev/null | \
  grep -E "\t<none>" | awk '{print $1}' | \
  xargs -r docker rmi -f 2>/dev/null || true

print_status "✅ Registry images cleaned up"
print_status "✅ All images pushed to registry"
print_status "📝 Use in Helm charts:"
print_status "  repository: ${DOCKER_REGISTRY_CLUSTER_URL:-docker-registry-service.dev.svc.cluster.local:5000}/$IMAGE_NAME"
print_status "  tag: latest"

# Final cleanup: ensure we only keep what we need
if [ "$CLEANUP_OLD_IMAGES" = true ]; then
  print_status "🧹 Final cleanup: removing old date-tagged images..."
  
  # Remove old date-tagged local images (keep only current DATE_TAG)
  # Match pattern: IMAGE_NAME:YYYYMMDD-HHMM
  docker images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | \
    grep -E "^$IMAGE_NAME:[0-9]{8}-[0-9]{4}$" | \
    grep -v "^$IMAGE_NAME:$DATE_TAG$" | \
    xargs -r docker rmi -f 2>/dev/null || true
  
  # Final pass: remove any remaining orphaned <none> tags
  docker images "$IMAGE_NAME" --format "{{.ID}}\t{{.Tag}}" 2>/dev/null | \
    grep -E "\t<none>" | awk '{print $1}' | \
    xargs -r docker rmi -f 2>/dev/null || true
  
  REGISTRY_URL="${DOCKER_REGISTRY_URL}"
  docker images "$REGISTRY_URL/$IMAGE_NAME" --format "{{.ID}}\t{{.Tag}}" 2>/dev/null | \
    grep -E "\t<none>" | awk '{print $1}' | \
    xargs -r docker rmi -f 2>/dev/null || true

  print_status "✅ Final cleanup complete"
fi
