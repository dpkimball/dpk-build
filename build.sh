#!/bin/bash
set -euo pipefail

# Load shared env defaults (assumes sourced by outer wrapper like bin/build.sh)
# This should already be done before calling this script
# source "$KEEPSAKE_SCRIPTS_ROOT/env.sh"
source "$KEEPSAKE_SCRIPTS_ROOT/utils.sh"

log_info "🐍 Ensuring virtualenv exists..."

if [[ "${1:-}" == "--clean" || ! -d "$PROJECT_VENV_DIR" || ! -f "$PROJECT_VENV_DIR/bin/activate" ]]; then
  log_info "🧹 Creating virtualenv at $PROJECT_VENV_DIR using $PYTHON_VERSION..."
  rm -rf "$PROJECT_VENV_DIR" uv.lock dist/
  uv virtualenv --python="$PYTHON_VERSION" "$PROJECT_VENV_DIR"
  source "$PROJECT_VENV_DIR/bin/activate"
  log_info "🔄 Installing all dependencies (including dev)..."
  # Explicitly set index URLs to ensure local PyPI is checked first (platform-specific)
  # Use unsafe-best-match to allow checking all indexes when package exists on public PyPI but has no versions
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

# ✅ Modular and conditional execution
if [[ "${SKIP_LINT:-false}" != "true" ]]; then
  log_info "🔄 Running lint..."
  "$KEEPSAKE_SCRIPTS_ROOT/lint.sh"
fi

if [[ "${SKIP_TESTS:-false}" != "true" ]]; then
  log_info "🔄 Running tests..."
  "$KEEPSAKE_SCRIPTS_ROOT/test.sh"
fi

if [[ "${SKIP_WHEEL:-false}" != "true" ]]; then
  log_info "🔄 Building wheel..."
  "$KEEPSAKE_SCRIPTS_ROOT/build-wheel.sh"
fi

if [[ "${SKIP_DOCKER_IMAGE:-false}" != "true" ]]; then
  log_info "🔄 Building Docker image..."
  "$KEEPSAKE_SCRIPTS_ROOT/build-docker-image.sh"
fi

if [[ "${SKIP_K8S_DEPLOY:-false}" != "true" && "${K8S_DEPLOY:-false}" = "true" ]]; then
  log_info "🔄 Deploying to Kubernetes..."
  "$KEEPSAKE_SCRIPTS_ROOT/deploy-k8s.sh"
fi
