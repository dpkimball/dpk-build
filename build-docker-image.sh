#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ -f .env.build ] && source .env.build

IMAGE_NAME="${IMAGE_NAME:-my_image}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
COMPOSE_SERVICE="${COMPOSE_SERVICE:-}"
SKIP_TESTS="${SKIP_TESTS:-false}"
CLEAN="${CLEAN:-false}"

print_status "🔍 Config: IMAGE_NAME=$IMAGE_NAME | CLEAN=$CLEAN | SKIP_TESTS=$SKIP_TESTS | COMPOSE_SERVICE=$COMPOSE_SERVICE"

if [ "$CLEAN" = true ]; then
  print_status "🧼 Cleaning previous Docker artifacts..."
  docker stop "$IMAGE_NAME" || true
  docker rm "$IMAGE_NAME" || true
  docker image rm "$IMAGE_NAME:latest" || true
fi

print_status "🐳 Building Docker image..."
DATE_TAG=$(date +"%Y%m%d-%H%M")
docker build --network host -t "$IMAGE_NAME:latest" -t "$IMAGE_NAME:$DATE_TAG" "$DOCKERFILE_DIR"

print_status "✅ Build complete. Tagged as $DATE_TAG"

if [ "$SKIP_TESTS" != true ]; then
  ./test.sh || print_warning "⚠ Tests failed"
fi

if [ -n "$COMPOSE_SERVICE" ]; then
  print_status "🔄 Replacing running container for service: $COMPOSE_SERVICE"

  docker compose -f "$KEEPSAKE_COMPOSE_PROJECT_ROOT/docker-compose.yml" stop "$COMPOSE_SERVICE" || true
  docker compose -f "$KEEPSAKE_COMPOSE_PROJECT_ROOT/docker-compose.yml" rm -f "$COMPOSE_SERVICE" || true
  docker compose -f "$KEEPSAKE_COMPOSE_PROJECT_ROOT/docker-compose.yml" up -d --no-deps "$COMPOSE_SERVICE"

  print_status "✅ Container for $COMPOSE_SERVICE restarted with updated image"
else
  print_warning "⚠ No COMPOSE_SERVICE specified, skipping container restart"
fi