#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

log_info "📦 Building Python wheel..."

# Ensure virtualenv exists
if [[ ! -d "$PROJECT_VENV_DIR" || ! -f "$PROJECT_VENV_DIR/bin/activate" ]]; then
  log_error "❌ Virtualenv not found at $PROJECT_VENV_DIR. Please run build.sh with --clean or ensure it exists."
  exit 1
fi

echo "📁 Working from: $PROJECT_ROOT"

# 🧮 Query PyPI server for latest version
echo "🔍 Checking latest version on local PyPI server..."
PACKAGE_NAME=$(sed -nE 's/^name = "([^"]+)"/\1/p' "$PYPROJECT" | head -n1)
LATEST_VERSION=$(uv pip index versions "$PACKAGE_NAME" --index-url "http://$PYPI_HOST:$PYPI_PORT" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)

if [[ -z "$LATEST_VERSION" ]]; then
  echo "⚠️  No versions found on PyPI. Defaulting to 0.0.0"
  LATEST_VERSION="0.0.0"
fi

IFS='.' read -r major minor patch <<< "$LATEST_VERSION"
NEW_VERSION="$major.$minor.$((patch + 1))"
echo "🔢 Bumping version: $LATEST_VERSION → $NEW_VERSION"

# Detect OS and use correct sed inline syntax
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' -E "s/^version = \".*\"/version = \"$NEW_VERSION\"/" "$PYPROJECT"
else
  sed -i -E "s/^version = \".*\"/version = \"$NEW_VERSION\"/" "$PYPROJECT"
fi

# 🧹 Clean previous build
echo "🧹 Cleaning build artifacts..."
rm -rf "$DIST_DIR" build/

# 📦 Build new wheel
echo "📦 Building wheel..."
uv run python -m build

# 📍 Get built wheel path
PACKAGE_NAME_UNDERSCORE="${PACKAGE_NAME//-/_}"
WHEEL_FILE=$(find "$DIST_DIR" -name "${PACKAGE_NAME_UNDERSCORE}-*.whl" | head -n1)

# Validate the result
if [[ -z "$WHEEL_FILE" ]]; then
  log_error "❌ No .whl file found for package '$PACKAGE_NAME' in $DIST_DIR"
  exit 1
fi

WHEEL_NAME=$(basename "$WHEEL_FILE")
echo "✅ Built wheel: $WHEEL_NAME"

# 📤 Upload to private PyPI via twine
echo "📤 Uploading $WHEEL_NAME to PyPI at $PYPI_HOST:$PYPI_PORT using twine..."

uv run twine upload \
  --repository-url "http://$PYPI_HOST:$PYPI_PORT" \
  --username "$PYPI_USERNAME" \
  --password "$PYPI_PASSWORD" \
  "$WHEEL_FILE" || {
    log_error "❌ Upload failed"
    exit 1
}

echo "✅ Wheel published to local PyPI."
echo "🕓 Completed on $(date)"
