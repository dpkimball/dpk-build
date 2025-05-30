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
  uv sync --dev
else
  source "$PROJECT_VENV_DIR/bin/activate"
fi

# ✅ Modular and conditional execution
if [[ "${SKIP_LINT:-false}" != "true" ]]; then
  "$KEEPSAKE_SCRIPTS_ROOT/lint.sh"
fi

if [[ "${SKIP_TESTS:-false}" != "true" ]]; then
  "$KEEPSAKE_SCRIPTS_ROOT/test.sh"
fi

if [[ "${SKIP_WHEEL:-false}" != "true" ]]; then
  "$KEEPSAKE_SCRIPTS_ROOT/build-wheel.sh"
fi

if [[ "${SKIP_WHEEL:-false}" != "true" ]]; then
  "$KEEPSAKE_SCRIPTS_ROOT/build-wheel.sh"
fi
