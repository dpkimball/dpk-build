#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ -f .env.build ] && source .env.build

IMAGE_NAME="${IMAGE_NAME:-my_image}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
COMPOSE_SERVICE="${COMPOSE_SERVICE:-}"
SKIP_TESTS="${SKIP_TESTS:-true}"
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

# Build command with optional build arguments
BUILD_CMD="docker build --network host"

# Add build arguments if environment variables are set
if [ -n "${UV_INDEX_URL:-}" ]; then
    BUILD_CMD="$BUILD_CMD --build-arg UV_INDEX_URL=\"$UV_INDEX_URL\""
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

# Add tags and build context
BUILD_CMD="$BUILD_CMD -t \"$IMAGE_NAME:latest\" -t \"$IMAGE_NAME:$DATE_TAG\" \"$DOCKERFILE_DIR\""

# Execute the build command
eval $BUILD_CMD

print_status "✅ Build complete. Tagged as $DATE_TAG"

if [ "$SKIP_TESTS" != true ]; then
  if [ -f "./test.sh" ]; then
    ./test.sh || print_warning "⚠ Tests failed"
  else
    print_warning "⚠ No test.sh found, skipping tests"
  fi
fi

# Deploy to Kubernetes if K8S_DEPLOY is specified
if [ "${K8S_DEPLOY:-false}" = "true" ]; then
  print_status "🚀 Deploying to Kubernetes..."
  
  # Load image into Kubernetes cluster
  if kubectl config current-context | grep -q "kind"; then
    print_status "🐳 Loading image into Kind cluster..."
    kind load docker-image "$IMAGE_NAME:latest" --name "${KIND_CLUSTER:-keepsake-dev}"
  elif kubectl config current-context | grep -q "docker-desktop\|rancher-desktop"; then
    print_status "🐳 Using Docker Desktop/Rancher Desktop (image already available)"
  elif kubectl config current-context | grep -q "minikube"; then
    print_status "🐳 Loading image into Minikube..."
    minikube image load "$IMAGE_NAME:latest"
  else
    print_warning "⚠️  Unknown Kubernetes cluster type. Image may not be available."
  fi
  
  # Update Helm deployment
  HELM_RELEASE="${HELM_RELEASE:-$IMAGE_NAME}"
  K8S_NAMESPACE="${K8S_NAMESPACE:-dev}"
  HELM_CHART_PATH="${HELM_CHART_PATH:-../keepsake-infra/charts/$IMAGE_NAME}"
  
  print_status "📦 Updating Helm release: $HELM_RELEASE in namespace: $K8S_NAMESPACE"
  print_status "📁 Using chart path: $HELM_CHART_PATH"
  
  # Check if chart path exists
  if [[ ! -d "$HELM_CHART_PATH" ]]; then
    print_error "❌ Helm chart not found at: $HELM_CHART_PATH"
    print_error "   Please set HELM_CHART_PATH to the correct chart directory"
    exit 1
  fi
  
  # Update the image in the Helm values
  helm upgrade "$HELM_RELEASE" \
    --namespace "$K8S_NAMESPACE" \
    --set image.repository="$IMAGE_NAME" \
    --set image.tag="latest" \
    --set image.pullPolicy="Never" \
    "$HELM_CHART_PATH" || {
    print_error "❌ Helm upgrade failed"
    exit 1
  }
  
  print_status "✅ Kubernetes deployment updated with local image"
elif [ -n "$COMPOSE_SERVICE" ]; then
  print_status "🔄 Replacing running container for service: $COMPOSE_SERVICE"

  docker compose -f "$KEEPSAKE_COMPOSE_PROJECT_ROOT/docker-compose.yml" stop "$COMPOSE_SERVICE" || true
  docker compose -f "$KEEPSAKE_COMPOSE_PROJECT_ROOT/docker-compose.yml" rm -f "$COMPOSE_SERVICE" || true
  docker compose -f "$KEEPSAKE_COMPOSE_PROJECT_ROOT/docker-compose.yml" up -d --no-deps "$COMPOSE_SERVICE"

  print_status "✅ Container for $COMPOSE_SERVICE restarted with updated image"
else
  print_warning "⚠ No COMPOSE_SERVICE or K8S_DEPLOY specified, skipping container restart"
fi