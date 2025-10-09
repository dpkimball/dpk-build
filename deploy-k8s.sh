#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

IMAGE_NAME="${IMAGE_NAME:-my_image}"

print_status "🚀 Deploying to Kubernetes..."

# Load image into Kubernetes cluster
CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')

if echo "$CURRENT_CONTEXT" | grep -q "kind"; then
  print_status "🐳 Loading image into Kind cluster..."
  kind load docker-image "$IMAGE_NAME:latest" --name "${KIND_CLUSTER:-keepsake-dev}"
elif echo "$CLUSTER_NAME" | grep -q "rancher-desktop" || echo "$CURRENT_CONTEXT" | grep -q "rancher-desktop"; then
  print_status "🐳 Using Rancher Desktop (image already available)"
elif echo "$CLUSTER_NAME" | grep -q "docker-desktop" || echo "$CURRENT_CONTEXT" | grep -q "docker-desktop"; then
  print_status "🐳 Using Docker Desktop (image already available)"
elif echo "$CURRENT_CONTEXT" | grep -q "minikube"; then
  print_status "🐳 Loading image into Minikube..."
  minikube image load "$IMAGE_NAME:latest"
else
  print_warning "⚠️  Unknown Kubernetes cluster type. Image may not be available."
  print_warning "   Context: $CURRENT_CONTEXT, Cluster: $CLUSTER_NAME"
fi

# Update Helm deployment(s)
K8S_NAMESPACE="${K8S_NAMESPACE:-dev}"

# Support multiple Helm releases (for projects like keepsake with multiple containers)
if [[ -n "${HELM_RELEASES:-}" ]]; then
  # Multiple releases specified (comma-separated)
  IFS=',' read -ra RELEASES <<< "$HELM_RELEASES"
  for release in "${RELEASES[@]}"; do
    release=$(echo "$release" | xargs) # trim whitespace
    HELM_CHART_PATH="../keepsake-infra/charts/$release"
    
    print_status "📦 Updating Helm release: $release in namespace: $K8S_NAMESPACE"
    print_status "📁 Using chart path: $HELM_CHART_PATH"
    
    # Check if chart path exists
    if [[ ! -d "$HELM_CHART_PATH" ]]; then
      print_error "❌ Helm chart not found at: $HELM_CHART_PATH"
      print_error "   Please set HELM_CHART_PATH to the correct chart directory"
      exit 1
    fi
    
    # Update the image in the Helm values
    helm upgrade "$release" \
      --namespace "$K8S_NAMESPACE" \
      --values "$HELM_CHART_PATH/values-dev.yaml" \
      --set image.repository="$IMAGE_NAME" \
      --set image.tag="latest" \
      --set image.pullPolicy="Never" \
      "$HELM_CHART_PATH" || {
      print_error "❌ Helm upgrade failed for $release"
      exit 1
    }
    
    print_status "✅ Kubernetes deployment updated for $release"
  done
else
  # Single release (backward compatibility)
  HELM_RELEASE="${HELM_RELEASE:-$IMAGE_NAME}"
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
    --values "$HELM_CHART_PATH/values-dev.yaml" \
    --set image.repository="$IMAGE_NAME" \
    --set image.tag="latest" \
    --set image.pullPolicy="Never" \
    "$HELM_CHART_PATH" || {
    print_error "❌ Helm upgrade failed"
    exit 1
  }
  
  print_status "✅ Kubernetes deployment updated with local image"
fi
