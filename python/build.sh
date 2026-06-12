#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

log_info "🐍 Ensuring virtualenv exists..."

if [[ "${1:-}" == "--clean" || ! -d "$PROJECT_VENV_DIR" || ! -f "$PROJECT_VENV_DIR/bin/activate" ]]; then
  log_info "🧹 Creating virtualenv at $PROJECT_VENV_DIR using $PYTHON_VERSION..."
  rm -rf "$PROJECT_VENV_DIR" uv.lock dist/
  uv virtualenv --python="$PYTHON_VERSION" "$PROJECT_VENV_DIR"
  source "$PROJECT_VENV_DIR/bin/activate"
  log_info "🔄 Installing all dependencies (including dev)..."
  if [[ -n "${UV_INDEX_URL:-}" ]]; then
    if [[ -n "${UV_EXTRA_INDEX_URL:-}" ]]; then
      uv sync --dev --default-index "$UV_INDEX_URL" --index "$UV_EXTRA_INDEX_URL" --index-strategy unsafe-best-match
    else
      uv sync --dev --default-index "$UV_INDEX_URL" --index-strategy unsafe-best-match
    fi
  else
    uv sync --dev
  fi
else
  source "$PROJECT_VENV_DIR/bin/activate"
fi

if [[ "${SKIP_LINT:-false}" != "true" ]]; then
  log_info "🔄 Running lint..."
  "$SCRIPT_DIR/../lint.sh"
fi

if [[ "${SKIP_TESTS:-false}" != "true" ]]; then
  log_info "🔄 Running tests..."
  "$SCRIPT_DIR/../test.sh"
fi

if [[ "${SKIP_WHEEL:-false}" != "true" ]]; then
  log_info "🔄 Building wheel..."
  "$SCRIPT_DIR/build-wheel.sh"
fi

if [[ "${SKIP_DOCKER_IMAGE:-false}" != "true" ]]; then
  log_info "🔄 Building Docker image..."
  "$SCRIPT_DIR/build-docker.sh"
fi

if [[ "${SKIP_K8S_DEPLOY:-false}" != "true" && "${K8S_DEPLOY:-false}" = "true" ]]; then
  log_info "🔄 Deploying to Kubernetes..."
  "$SCRIPT_DIR/deploy-k8s.sh"
fi
