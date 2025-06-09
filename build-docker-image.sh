set -euo pipefail
source "$(dirname "$0")/common.sh"

[ -f .env.build ] && source .env.build

IMAGE_NAME="${IMAGE_NAME:-my_image}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
SKIP_TESTS="${SKIP_TESTS:-false}"
CLEAN="${CLEAN:-false}"

print_status "🔍 Config: IMAGE_NAME=$IMAGE_NAME | CLEAN=$CLEAN | SKIP_TESTS=$SKIP_TESTS"

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