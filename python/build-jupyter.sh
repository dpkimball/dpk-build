#!/bin/bash
set -euo pipefail

source "$BUILD_ROOT/utils.sh"

log_info "🐍 Ensuring virtualenv exists..."

if [[ "${1:-}" == "--clean" || ! -d "$PROJECT_JUPYTER_VENV_DIR" || ! -f "$PROJECT_JUPYTER_VENV_DIR/bin/activate" ]]; then
  log_info "🧹 Creating virtualenv at $PROJECT_JUPYTER_VENV_DIR using $PYTHON_VERSION..."
  rm -rf "$PROJECT_JUPYTER_VENV_DIR" uv.lock dist/
  uv virtualenv --python="$PYTHON_VERSION" "$PROJECT_JUPYTER_VENV_DIR"
  source "$PROJECT_JUPYTER_VENV_DIR/bin/activate"
  log_info "🔄 Installing all dependencies (including dev)..."
  uv sync --dev
else
  source "$PROJECT_JUPYTER_VENV_DIR/bin/activate"
fi

# build jupyter
echo "📦 Installing Jupyter kernel tools..."
uv pip install ipykernel jupyterlab

PACKAGE_NAME=$(sed -nE 's/^name = "([^"]+)"/\1/p' "$PYPROJECT" | head -n1)
PACKAGE_DESC=$(sed -nE 's/^description = "([^"]+)"/\1/p' "$PYPROJECT" | head -n1)

echo "🧠 Registering kernel 'keepsake-image' with display name '📝 Keepsake Image AI'..."
.venv/bin/python -m ipykernel install --user --name "$PACKAGE_NAME" --display-name "$PACKAGE_DESC"

echo "🚀 Launching Jupyter Lab..."
.venv/bin/jupyter lab

