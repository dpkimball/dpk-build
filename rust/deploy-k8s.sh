#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

IMAGE_NAME="${IMAGE_NAME:-memory-graph-service}"
K8S_NAMESPACE="${K8S_NAMESPACE:-dev}"

log_step "🚀 Deploying Rust service to Kubernetes..."

CLUSTER_TYPE="$("$SCRIPT_DIR/../shared/detect-cluster.sh")"

case "$CLUSTER_TYPE" in
  kind)
    log_info "🐳 Loading image into Kind cluster..."
    kind load docker-image "$IMAGE_NAME:latest" --name "${KIND_CLUSTER:-keepsake-dev}"
    log_success "✅ Image loaded into Kind cluster"
    ;;
  rancher-desktop|docker-desktop)
    log_info "🐳 Using $CLUSTER_TYPE (image already available)"
    ;;
  minikube)
    log_info "🐳 Loading image into Minikube..."
    minikube image load "$IMAGE_NAME:latest"
    log_success "✅ Image loaded into Minikube"
    ;;
  *)
    log_warning "Unknown cluster type — image may not be available"
    ;;
esac

if [[ -n "${HELM_RELEASE:-}" ]]; then
  HELM_CHART_PATH="${HELM_CHART_PATH:-${WORKSPACE_ROOT}/dpk-infra/charts/$HELM_RELEASE}"
  log_info "📦 Helm upgrade: $HELM_RELEASE in $K8S_NAMESPACE"

  if [[ ! -d "$HELM_CHART_PATH" ]]; then
    log_error "Helm chart not found at: $HELM_CHART_PATH"
    exit 1
  fi

  helm upgrade --install "$HELM_RELEASE" \
    --namespace "$K8S_NAMESPACE" \
    --create-namespace \
    --values "$HELM_CHART_PATH/values-dev.yaml" \
    --set image.repository="${DOCKER_REGISTRY_URL}/$IMAGE_NAME" \
    --set image.tag="latest" \
    --set image.pullPolicy="Always" \
    "$HELM_CHART_PATH"

  kubectl rollout status deployment/"$HELM_RELEASE" --namespace "$K8S_NAMESPACE" --timeout=300s
  log_success "✅ $HELM_RELEASE deployed"
else
  log_info "💡 Set HELM_RELEASE to deploy via Helm"
fi
