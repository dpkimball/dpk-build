#!/bin/bash
# Java build: Maven package, then optional image/deploy (legacy direct invocation).
# Prefer `dpk-build deliver` (Rust CLI).
set -euo pipefail
_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$_SCRIPTS_DIR/../env.sh"
# shellcheck source=/dev/null
source "$_SCRIPTS_DIR/../common.sh"
# shellcheck source=/dev/null
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"
# shellcheck source=/dev/null
[ -f "$PWD/scripts/runtime-env.sh" ] && source "$PWD/scripts/runtime-env.sh"
# shellcheck source=/dev/null
source "$_SCRIPTS_DIR/mvn-run.sh"

if [[ "${SKIP_BUILD:-false}" != "true" ]]; then
  POM="$(resolve_maven_pom)"
  log_info "☕ Maven package ($POM)"
  run_maven -DskipTests package
fi

if [[ "${SKIP_DOCKER_IMAGE:-false}" != "true" ]]; then
  log_info "🐳 Building Docker image..."
  "$_SCRIPTS_DIR/../build-docker-image.sh"
fi

if [[ "${SKIP_K8S_DEPLOY:-false}" != "true" && "${K8S_DEPLOY:-false}" = "true" ]]; then
  log_info "🚀 Deploying to Kubernetes..."
  "$_SCRIPTS_DIR/../deploy-k8s.sh"
fi
