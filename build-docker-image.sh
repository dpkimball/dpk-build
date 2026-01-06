#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ -f .env.build ] && source .env.build

IMAGE_NAME="${IMAGE_NAME:-my_image}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
CLEAN="${CLEAN:-false}"
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

print_status "🐳 Building Docker image..."
DATE_TAG=$(date +"%Y%m%d-%H%M")

# Debug: Show UV_INDEX_URL_BUILD before build
_UV_URL_FOR_BUILD="${UV_INDEX_URL_BUILD:-${UV_INDEX_URL:-}}"
print_status "🔍 Debug: UV_INDEX_URL_BUILD=${UV_INDEX_URL_BUILD:-not set}"
print_status "🔍 Debug: UV_INDEX_URL=${UV_INDEX_URL:-not set}"
print_status "🔍 Debug: Using for build: ${_UV_URL_FOR_BUILD:-not set}"

# Build command with optional build arguments
# Use --pull=false when DOCKER_BUILD_PULL is set to false (for local images)
BUILD_CMD="docker build --network host"
if [ "${DOCKER_BUILD_PULL:-}" = "false" ]; then
    BUILD_CMD="$BUILD_CMD --pull=false"
fi

# Add build arguments if environment variables are set
# BASE_IMAGE: Use local base image if available, otherwise use GHCR
if [ -n "${BASE_IMAGE:-}" ]; then
    BUILD_CMD="$BUILD_CMD --build-arg BASE_IMAGE=\"$BASE_IMAGE\""
fi
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
