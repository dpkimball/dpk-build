#!/bin/bash
# Java/Flink services: Docker build+push, then optional K8s deploy.
# No Python venv, wheel, or lint steps.
set -euo pipefail
_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_SCRIPTS_DIR/../env.sh"
source "$_SCRIPTS_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

if [[ "${SKIP_DOCKER_IMAGE:-false}" != "true" ]]; then
  log_info "🐳 Building Docker image..."
  "$_SCRIPTS_DIR/../build-docker-image.sh"
fi

if [[ "${SKIP_K8S_DEPLOY:-false}" != "true" && "${K8S_DEPLOY:-false}" = "true" ]]; then
  log_info "🚀 Deploying to Kubernetes..."
  "$_SCRIPTS_DIR/../deploy-k8s.sh"
fi
