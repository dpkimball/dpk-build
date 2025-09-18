#!/usr/bin/env bash
set -euo pipefail

# Load shared utilities
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

# Load environment variables
[ -f .env.build ] && source .env.build

# Default values
IMAGE_NAME="${IMAGE_NAME:-memory-graph-service}"
K8S_NAMESPACE="${K8S_NAMESPACE:-dev}"
KIND_CLUSTER="${KIND_CLUSTER:-keepsake-dev}"

log_info "🚀 Loading local Docker image into Kubernetes cluster..."
log_info "🔍 Config: IMAGE_NAME=$IMAGE_NAME | K8S_NAMESPACE=$K8S_NAMESPACE | KIND_CLUSTER=$KIND_CLUSTER"

# Check if we're in a Rust project
if [[ ! -f "Cargo.toml" ]]; then
  log_error "❌ Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

# Check if Docker image exists
if ! docker image inspect "$IMAGE_NAME:latest" >/dev/null 2>&1; then
  log_error "❌ Docker image $IMAGE_NAME:latest not found. Please build it first with:"
  log_error "  $KEEPSAKE_SCRIPTS_ROOT/rust_docker_build.sh"
  exit 1
fi

# Detect Kubernetes cluster type and load image accordingly
if kubectl config current-context | grep -q "kind"; then
  log_info "🐳 Detected Kind cluster, loading image..."
  kind load docker-image "$IMAGE_NAME:latest" --name "$KIND_CLUSTER"
  log_success "✅ Image loaded into Kind cluster: $KIND_CLUSTER"
  
elif kubectl config current-context | grep -q "docker-desktop\|rancher-desktop"; then
  log_info "🐳 Detected Docker Desktop/Rancher Desktop, image should be available"
  log_info "💡 Docker Desktop/Rancher Desktop shares Docker daemon with Kubernetes"
  
elif kubectl config current-context | grep -q "minikube"; then
  log_info "🐳 Detected Minikube, loading image..."
  minikube image load "$IMAGE_NAME:latest"
  log_success "✅ Image loaded into Minikube"
  
else
  log_warning "⚠️  Unknown Kubernetes cluster type. Image may not be available."
  log_info "💡 For remote clusters, you may need to push to a registry or use image pull secrets"
fi

# Verify the image is available in the cluster
log_info "🔍 Verifying image availability..."
if kubectl get nodes -o jsonpath='{.items[*].status.images[*].names[*]}' | grep -q "$IMAGE_NAME"; then
  log_success "✅ Image $IMAGE_NAME:latest is available in the cluster"
else
  log_warning "⚠️  Image may not be available in all nodes"
fi

log_success "🎉 Image loading complete!"
log_info "💡 Next steps:"
log_info "  • Deploy to dev environment: $KEEPSAKE_SCRIPTS_ROOT/rust_deploy_k8s.sh"
log_info "  • Or use: make k8s-deploy (from memory-graph-service directory)"
