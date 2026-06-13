#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

[ -f .env.build ] && source .env.build

IMAGE_NAME="${IMAGE_NAME:-memory-graph-service}"
KIND_CLUSTER="${KIND_CLUSTER:-keepsake-dev}"

log_info "🚀 Loading local Docker image into Kubernetes cluster..."

if ! docker image inspect "$IMAGE_NAME:latest" >/dev/null 2>&1; then
  log_error "Docker image $IMAGE_NAME:latest not found. Build it first with rust/build-docker.sh"
  exit 1
fi

CLUSTER_TYPE="$("$SCRIPT_DIR/../shared/detect-cluster.sh")"

case "$CLUSTER_TYPE" in
  kind)
    log_info "🐳 Loading image into Kind cluster..."
    kind load docker-image "$IMAGE_NAME:latest" --name "$KIND_CLUSTER"
    log_success "✅ Image loaded into Kind cluster: $KIND_CLUSTER"
    ;;
  rancher-desktop|docker-desktop)
    log_info "🐳 $CLUSTER_TYPE shares Docker daemon — image already available"
    ;;
  minikube)
    log_info "🐳 Loading image into Minikube..."
    minikube image load "$IMAGE_NAME:latest"
    log_success "✅ Image loaded into Minikube"
    ;;
  *)
    log_warning "Unknown cluster type. Image may not be available for remote clusters."
    ;;
esac

log_success "🎉 Image loading complete!"
