#!/bin/bash
set -euo pipefail

# Load shared utilities
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

# Load environment variables
[ -f .env.build ] && source .env.build

# Default values
IMAGE_NAME="${IMAGE_NAME:-memory-graph-service}"
CONTAINER_NAME="${CONTAINER_NAME:-memory-graph-service-dev}"
NAMESPACE="${NAMESPACE:-dev}"
CLEAN="${CLEAN:-false}"

log_info "🚀 Launching Rust container in dev environment..."
log_info "🔍 Config: IMAGE_NAME=$IMAGE_NAME | CONTAINER_NAME=$CONTAINER_NAME | NAMESPACE=$NAMESPACE"

# Check if we're in a Rust project
if [[ ! -f "Cargo.toml" ]]; then
  log_error "Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

# Check if Docker image exists
if ! docker image inspect "$IMAGE_NAME:latest" >/dev/null 2>&1; then
  log_error "Docker image $IMAGE_NAME:latest not found. Please build it first with:"
  log_error "  $BUILD_ROOT/rust_docker_build.sh"
  exit 1
fi

if [ "$CLEAN" = true ]; then
  log_info "🧼 Cleaning previous container..."
  docker stop "$CONTAINER_NAME" || true
  docker rm "$CONTAINER_NAME" || true
fi

# Check if container is already running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
  log_info "🔄 Container $CONTAINER_NAME is already running. Stopping and removing..."
  docker stop "$CONTAINER_NAME"
  docker rm "$CONTAINER_NAME"
fi

# Load environment variables from config.env if it exists
ENV_ARGS=""
if [[ -f "config.env" ]]; then
  log_info "📋 Loading environment variables from config.env..."
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    # Add environment variable
    ENV_ARGS="$ENV_ARGS -e $line"
  done < config.env
fi

log_info "🐳 Starting container $CONTAINER_NAME..."

# Run the container with appropriate networking and environment
docker run -d \
  --name "$CONTAINER_NAME" \
  --network host \
  $ENV_ARGS \
  -e RUST_LOG="${RUST_LOG:-info}" \
  -e MONGODB_URI="${MONGODB_URI:-mongodb://keepsake_user:keepsake_pass@localhost:27017/keepsake?authSource=keepsake}" \
  -e WEAVIATE_BASE_URL="${WEAVIATE_BASE_URL:-http://localhost:8080}" \
  -e NEO4J_URI="${NEO4J_URI:-bolt://localhost:7687}" \
  -e NEO4J_USER="${NEO4J_USER:-neo4j}" \
  -e NEO4J_PASSWORD="${NEO4J_PASSWORD:-password}" \
  -e SYNC_ENABLED="${SYNC_ENABLED:-true}" \
  -e SYNC_INTERVAL_SECONDS="${SYNC_INTERVAL_SECONDS:-60}" \
  -e SYNC_COLLECTIONS="${SYNC_COLLECTIONS:-memory_orb,observation,perspective}" \
  -e EMBEDDING_VERSION="${EMBEDDING_VERSION:-v1.0}" \
  "$IMAGE_NAME:latest"

log_success "✅ Container $CONTAINER_NAME started successfully!"

# Show container status
log_info "📊 Container status:"
docker ps -f name="$CONTAINER_NAME"

# Show logs
log_info "📝 Container logs (last 10 lines):"
docker logs --tail 10 "$CONTAINER_NAME"

log_success "🎉 Rust container launched in dev environment!"
log_info "💡 Useful commands:"
log_info "  • View logs: docker logs -f $CONTAINER_NAME"
log_info "  • Stop container: docker stop $CONTAINER_NAME"
log_info "  • Remove container: docker rm $CONTAINER_NAME"
log_info "  • Shell into container: docker exec -it $CONTAINER_NAME /bin/bash"
