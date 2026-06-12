#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

IMAGE_NAME="${IMAGE_NAME:-my_image}"

log_step "🚀 Deploying to Kubernetes..."

CLUSTER_TYPE="$("$SCRIPT_DIR/../shared/detect-cluster.sh")"

case "$CLUSTER_TYPE" in
  kind)
    log_info "🐳 Loading image into Kind cluster..."
    kind load docker-image "$IMAGE_NAME:latest" --name "${KIND_CLUSTER:-keepsake-dev}"
    ;;
  rancher-desktop)
    log_info "🐳 Using Rancher Desktop (image already available)"
    ;;
  docker-desktop)
    log_info "🐳 Using Docker Desktop (image already available)"
    ;;
  minikube)
    log_info "🐳 Loading image into Minikube..."
    minikube image load "$IMAGE_NAME:latest"
    ;;
  *)
    log_warning "Unknown Kubernetes cluster type. Image may not be available."
    ;;
esac

# Update Helm deployment(s)
K8S_NAMESPACE="${K8S_NAMESPACE:-dev}"

wait_for_resource_ready() {
  local name="$1"
  local ns="$2"
  local kind=""
  local job_name="$name"
  local tries=0
  local max_tries=5

  if [[ "$name" == *prestart* ]]; then
    print_status "📦 (hint) '$name' looks like a prestart job — waiting for Job completion..."
    if ! kubectl wait --namespace "$ns" --for=condition=complete --timeout=300s job/"$name"; then
      print_error "❌ Job $name did not complete successfully (ns=$ns)"
      kubectl logs --namespace "$ns" --selector=job-name="$name" --all-containers=true --tail=200 || true
      exit 1
    fi
    print_status "✅ Job $name completed"
    return 0
  fi

  print_status "🔎 Looking for resource '$name' in namespace '$ns'..."

  while [[ $tries -lt $max_tries ]]; do
    # 1) try app=<name>
    kind=$(kubectl get all \
      --namespace "$ns" \
      --selector=app="$name" \
      -o jsonpath='{.items[0].kind}' 2>/dev/null || true)
    if [[ "$kind" == "List" || "$kind" == "" ]]; then
      kind=""
    fi

    # 2) try direct name (job or deployment)
    if [[ -z "$kind" ]]; then
      kind=$(kubectl get job,deploy "$name" \
        --namespace "$ns" \
        -o jsonpath='{.kind}' 2>/dev/null || true)
      if [[ "$kind" == "List" || "$kind" == "" ]]; then
        kind=""
      fi
    fi

    # Added explicit fallbacks
    if [[ -z "$kind" ]]; then
      kind=$(kubectl get deployment "$name" --namespace "$ns" -o jsonpath='{.kind}' 2>/dev/null || true)
      if [[ "$kind" == "List" || "$kind" == "" ]]; then
        kind=""
      fi
    fi

    if [[ -z "$kind" ]]; then
      kind=$(kubectl get job "$name" --namespace "$ns" -o jsonpath='{.kind}' 2>/dev/null || true)
      if [[ "$kind" == "List" || "$kind" == "" ]]; then
        kind=""
      fi
    fi

    # 3) try job-name=<name> (common for Job pods)
    if [[ -z "$kind" ]]; then
      job_name=$(kubectl get job \
        --namespace "$ns" \
        --selector=job-name="$name" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
      if [[ -n "$job_name" ]]; then
        kind="Job"
      fi
    fi

    # 4) fallback to default namespace once if nothing found
    if [[ -z "$kind" && $tries -eq 0 ]]; then
      local def_job
      def_job=$(kubectl get job "$name" \
        --namespace default \
        -o jsonpath='{.metadata.name}' 2>/dev/null || true)
      if [[ -n "$def_job" ]]; then
        ns="default"
        job_name="$def_job"
        kind="Job"
      fi
    fi

    if [[ -n "$kind" ]]; then
      break
    fi

    tries=$((tries+1))
    print_status "⏳ Resource '$name' not visible yet (try $tries/$max_tries)..."
    sleep 2
  done

  if [[ "$kind" == "List" ]]; then
    local try_kind
    try_kind=$(kubectl get job "$name" --namespace "$ns" -o jsonpath='{.kind}' 2>/dev/null || true)
    if [[ "$try_kind" == "Job" ]]; then
      kind="Job"
    else
      try_kind=$(kubectl get deployment "$name" --namespace "$ns" -o jsonpath='{.kind}' 2>/dev/null || true)
      if [[ -n "$try_kind" ]]; then
        kind="$try_kind"
      fi
    fi
  fi

  if [[ -z "$kind" ]]; then
    print_error "⚠️ Unable to determine resource type for $name in namespace $ns"
    kubectl get all --namespace "$ns" | grep "$name" || true
    exit 1
  fi

  if [[ "$kind" == "Job" ]]; then
    print_status "📦 Detected Job $name in ns=$ns — waiting for completion..."
    if ! kubectl wait --namespace "$ns" \
      --for=condition=complete \
      --timeout=300s \
      job/"$job_name"; then
      print_error "❌ Job $name did not complete successfully (ns=$ns)"
      kubectl logs --namespace "$ns" \
        --selector=job-name="$name" --all-containers=true --tail=200 || true
      exit 1
    fi
    print_status "✅ Job $name completed"
  elif [[ "$kind" == "Deployment" ]]; then
    print_status "🔁 Forcing rollout restart for deployment/$name (tag=latest or no spec change detected)..."
    kubectl rollout restart deployment/"$name" --namespace "$ns" >/dev/null 2>&1 || true

    print_status "📦 Detected Deployment $name in ns=$ns — waiting for rollout..."
    if ! kubectl rollout status deployment/"$name" \
      --namespace "$ns" --timeout=300s; then
      print_error "❌ Deployment $name failed to become ready (ns=$ns)"
      exit 1
    fi
    print_status "✅ Deployment $name is ready"
  else
    print_error "⚠️ Resource $name is of kind '$kind' which is not handled"
    exit 1
  fi
}

# Support multiple Helm releases (for projects like keepsake with multiple containers)
# Prefer explicit HELM_RELEASE (single chart) over inherited HELM_RELEASES from another
# project's shell — e.g. resume-pipeline must deploy dagster-resume, not keepsake-prestart.
if [[ -n "${HELM_RELEASE:-}" ]]; then
  HELM_CHART_PATH="${HELM_CHART_PATH:-$KEEPSAKE_PROJECT_ROOT/keepsake-infra/charts/$HELM_RELEASE}"

  print_status "📦 Updating Helm release: $HELM_RELEASE in namespace: $K8S_NAMESPACE"
  print_status "📁 Using chart path: $HELM_CHART_PATH"

  if [[ ! -d "$HELM_CHART_PATH" ]]; then
    print_error "❌ Helm chart not found at: $HELM_CHART_PATH"
    print_error "   Set HELM_CHART_PATH to the correct chart directory"
    exit 1
  fi

  REGISTRY_URL="${DOCKER_REGISTRY_URL}"
  IMAGE_REPOSITORY="$REGISTRY_URL/$IMAGE_NAME"

  print_status "🖼️  Using image: $IMAGE_REPOSITORY:latest"

  helm upgrade --install "$HELM_RELEASE" \
    --namespace "$K8S_NAMESPACE" \
    --create-namespace \
    --values "$HELM_CHART_PATH/values-dev.yaml" \
    --set image.repository="$IMAGE_REPOSITORY" \
    --set image.tag="latest" \
    --set image.pullPolicy="Always" \
    "$HELM_CHART_PATH" || {
    print_error "❌ Helm upgrade/install failed"
    exit 1
  }

  print_status "✅ Kubernetes deployment updated with local image"
  wait_for_resource_ready "$HELM_RELEASE" "$K8S_NAMESPACE"
elif [[ -n "${HELM_RELEASES:-}" ]]; then
  # Multiple releases specified (comma-separated)
  IFS=',' read -ra RELEASES <<< "$HELM_RELEASES"
  for release in "${RELEASES[@]}"; do
    release=$(echo "$release" | xargs) # trim whitespace
    HELM_CHART_PATH="$KEEPSAKE_PROJECT_ROOT/keepsake-infra/charts/$release"

    print_status "📦 Updating Helm release: $release in namespace: $K8S_NAMESPACE"
    print_status "📁 Using chart path: $HELM_CHART_PATH"

    # Check if chart path exists
    if [[ ! -d "$HELM_CHART_PATH" ]]; then
      print_error "❌ Helm chart not found at: $HELM_CHART_PATH"
      print_error "   Please set HELM_CHART_PATH to the correct chart directory"
      exit 1
    fi

    # Determine image name for this release
    # Default to release name if IMAGE_NAME doesn't match, or use IMAGE_NAME if it matches release
    if [[ "$release" == *"frontend"* ]] && [[ "$IMAGE_NAME" != *"frontend"* ]]; then
      # Release is frontend but IMAGE_NAME is backend - use release name as image
      RELEASE_IMAGE_NAME="$release"
    elif [[ "$release" == *"backend"* ]] && [[ "$IMAGE_NAME" != *"backend"* ]]; then
      # Release is backend but IMAGE_NAME is frontend - use release name as image
      RELEASE_IMAGE_NAME="$release"
    else
      # Use IMAGE_NAME as-is (matches release or is generic)
      RELEASE_IMAGE_NAME="$IMAGE_NAME"
    fi

    # Construct registry URL for image repository
    REGISTRY_URL="${DOCKER_REGISTRY_URL}"
    RELEASE_IMAGE_REPOSITORY="$REGISTRY_URL/$RELEASE_IMAGE_NAME"
    
    print_status "🖼️  Using image: $RELEASE_IMAGE_REPOSITORY:latest"

    # Update the image in the Helm values
    # Use --install to create release if it doesn't exist
    helm upgrade --install "$release" \
      --namespace "$K8S_NAMESPACE" \
      --create-namespace \
      --values "$HELM_CHART_PATH/values-dev.yaml" \
      --set image.repository="$RELEASE_IMAGE_REPOSITORY" \
      --set image.tag="latest" \
      --set image.pullPolicy="Always" \
      "$HELM_CHART_PATH" || {
      print_error "❌ Helm upgrade/install failed for $release"
      exit 1
    }

    print_status "✅ Kubernetes deployment updated for $release"

    # Wait for deployment to be ready
    wait_for_resource_ready "$release" "$K8S_NAMESPACE"
  done
else
  # Single release — default chart/release name follows IMAGE_NAME
  HELM_RELEASE="${HELM_RELEASE:-$IMAGE_NAME}"
  HELM_CHART_PATH="${HELM_CHART_PATH:-$KEEPSAKE_PROJECT_ROOT/keepsake-infra/charts/$IMAGE_NAME}"

  print_status "📦 Updating Helm release: $HELM_RELEASE in namespace: $K8S_NAMESPACE"
  print_status "📁 Using chart path: $HELM_CHART_PATH"

  # Check if chart path exists
  if [[ ! -d "$HELM_CHART_PATH" ]]; then
    print_error "❌ Helm chart not found at: $HELM_CHART_PATH"
    print_error "   Please set HELM_CHART_PATH to the correct chart directory"
    exit 1
  fi

  # Construct registry URL for image repository
  REGISTRY_URL="${DOCKER_REGISTRY_URL}"
  IMAGE_REPOSITORY="$REGISTRY_URL/$IMAGE_NAME"
  
  # Update the image in the Helm values
  # Use --install to create release if it doesn't exist
  helm upgrade --install "$HELM_RELEASE" \
    --namespace "$K8S_NAMESPACE" \
    --create-namespace \
    --values "$HELM_CHART_PATH/values-dev.yaml" \
    --set image.repository="$IMAGE_REPOSITORY" \
    --set image.tag="latest" \
    --set image.pullPolicy="Always" \
    "$HELM_CHART_PATH" || {
    print_error "❌ Helm upgrade/install failed"
    exit 1
  }

  print_status "✅ Kubernetes deployment updated with local image"

  # Wait for deployment to be ready
  wait_for_resource_ready "$HELM_RELEASE" "$K8S_NAMESPACE"
fi
