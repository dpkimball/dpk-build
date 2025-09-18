#!/usr/bin/env bash
set -euo pipefail

# 🌐 Load shared utils and env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$KEEPSAKE_SCRIPTS_ROOT/env.sh"

# 🔧 Override PyPI settings for local development if set
if [[ -n "${PYPI_HOST_OVERRIDE:-}" ]]; then
  export PYPI_HOST="$PYPI_HOST_OVERRIDE"
fi

log_info "📦 Building Python wheel..."

# 📁 Required paths
PROJECT_VENV_DIR="${PROJECT_VENV_DIR:-.venv}"
PYPROJECT="${PYPROJECT:-$PROJECT_ROOT/pyproject.toml}"
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"

# Validate virtualenv
if [[ ! -d "$PROJECT_VENV_DIR" || ! -f "$PROJECT_VENV_DIR/bin/activate" ]]; then
  log_error "❌ Virtualenv not found at $PROJECT_VENV_DIR. Please run build.sh with --clean or ensure it exists."
  exit 1
fi

log_info "📁 Working from: $PROJECT_ROOT"

# 🔍 Extract package name from pyproject.toml
PACKAGE_LINE=$(grep -E '^\s*name\s*=' "$PYPROJECT" | head -n1)
PACKAGE_NAME=$(echo "$PACKAGE_LINE" | awk -F '=' '{gsub(/"/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

if [[ -z "$PACKAGE_NAME" ]]; then
  log_error "❌ Could not extract package name from $PYPROJECT"
  exit 1
fi

log_info "🔍 Package name: $PACKAGE_NAME"

# 🔍 Get latest version from local PyPI
log_info "🔍 Querying local PyPI for latest $PACKAGE_NAME version..."
GET_VERSION_SCRIPT="$KEEPSAKE_SCRIPTS_ROOT/get_latest_pypi_version.sh"

if [[ ! -x "$GET_VERSION_SCRIPT" ]]; then
  log_error "❌ Version script not found or not executable: $GET_VERSION_SCRIPT"
  exit 1
fi

LATEST_VERSION="$("$GET_VERSION_SCRIPT" "$PACKAGE_NAME")"
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  log_error "❌ Version script failed with exit code $EXIT_CODE"
  exit $EXIT_CODE
fi

log_info "🔢 Latest version on PyPI: $LATEST_VERSION"

if [[ -z "$LATEST_VERSION" ]]; then
  log_info "⚠️  No versions found on PyPI. Defaulting to 0.0.0"
  LATEST_VERSION="0.0.0"
fi

MAJOR=$(echo "$LATEST_VERSION" | cut -d. -f1)
MINOR=$(echo "$LATEST_VERSION" | cut -d. -f2)
PATCH=$(echo "$LATEST_VERSION" | cut -d. -f3)
PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

# 📝 Update pyproject.toml version
log_info "📝 Updating version in pyproject.toml to $NEW_VERSION"

if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' -E "s/^[[:space:]]*version[[:space:]]*=[[:space:]]*\"[^\"]+\"/version = \"$NEW_VERSION\"/" "$PYPROJECT"
else
  sed -i -E "s/^[[:space:]]*version[[:space:]]*=[[:space:]]*\"[^\"]+\"/version = \"$NEW_VERSION\"/" "$PYPROJECT"
fi
# 🧹 Clean old builds
log_info "🧹 Cleaning old artifacts..."
rm -rf "$DIST_DIR" build/ *.egg-info

# 🛠️ Build wheel
log_info "📦 Building wheel with uv..."
uv run python -m build

# ✅ Confirm output
PACKAGE_NAME_UNDERSCORE="${PACKAGE_NAME//-/_}"
WHEEL_FILE=$(find "$DIST_DIR" -name "${PACKAGE_NAME_UNDERSCORE}-*.whl" | head -n1)
if [[ -z "$WHEEL_FILE" ]]; then
  log_error "❌ No .whl file found for package '$PACKAGE_NAME'"
  exit 1
fi

log_info "✅ Built: $(basename "$WHEEL_FILE")"

# 🚀 Upload to local PyPI
log_info "📤 Uploading to PyPI ($PYPI_HOST:$PYPI_PORT)..."
uv run twine upload \
  --repository-url "http://$PYPI_HOST:$PYPI_PORT" \
  --username "$PYPI_USERNAME" \
  --password "$PYPI_PASSWORD" \
  "$WHEEL_FILE" || {
    log_error "❌ Upload failed"
    exit 1
  }

log_info "✅ Upload complete for $PACKAGE_NAME@$NEW_VERSION"
log_info "🕓 Finished at $(date)"
