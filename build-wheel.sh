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

# 🔢 Auto-increment patch version (POSIX-compatible)
OLD_VERSION=$(sed -nE 's/^version = "([^"]+)"/\1/p' "$PYPROJECT" | head -n1)
IFS='.' read -r major minor patch <<< "$OLD_VERSION"
NEW_VERSION="$major.$minor.$((patch + 1))"
echo "🔢 Bumping version: $OLD_VERSION → $NEW_VERSION"

# Detect OS and use correct sed inline syntax
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' -E "s/^version = \"$OLD_VERSION\"/version = \"$NEW_VERSION\"/" "$PYPROJECT"
else
  sed -i -E "s/^version = \"$OLD_VERSION\"/version = \"$NEW_VERSION\"/" "$PYPROJECT"
fi

# 🧹 Clean previous build
echo "🧹 Cleaning build artifacts..."
rm -rf "$DIST_DIR" build/

# 📦 Build new wheel
echo "📦 Building wheel..."
uv run python -m build

# 📍 Get built wheel path
# Get package name from pyproject.toml
PACKAGE_NAME=$(sed -nE 's/^name = "([^"]+)"/\1/p' "$PYPROJECT" | head -n1)

# Convert hyphens to underscores for file matching
PACKAGE_NAME_UNDERSCORE="${PACKAGE_NAME//-/_}"

# Find the built wheel file
WHEEL_FILE=$(find "$DIST_DIR" -name "${PACKAGE_NAME_UNDERSCORE}-*.whl" | head -n1)

# Validate the result
if [[ -z "$WHEEL_FILE" ]]; then
  log_error "❌ No .whl file found for package '$PACKAGE_NAME' in $DIST_DIR"
  exit 1
fi

WHEEL_NAME=$(basename "$WHEEL_FILE")
echo "✅ Built wheel: $WHEEL_NAME"

# Copy to local PyPI package directory
#DEST="$PYPI_PACKAGE_DIR/$WHEEL_NAME"
#echo "📤 Copying to: $DEST"
#cp "$WHEEL_FILE" "$DEST"

# 🧪 Optional: Validate that your PyPI server is reachable
#curl --fail-with-body --silent --show-error -u "$PYPI_USERNAME:$PYPI_PASSWORD" \
#     -F "content=@$WHEEL_FILE" \
#     "http://$PYPI_HOST:$PYPI_PORT/" || {
#  log_error "❌ Upload failed"
#  exit 1
#}

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

# Normalize package name for env var key
PACKAGE_KEY="$(echo "${PACKAGE_NAME}" | tr '[:lower:]-' '[:upper:]_')"

# Remove existing line for this package if present
sed -i.bak "/^${PACKAGE_KEY}_VERSION=/d" "$ENV_STORE"

# Append updated version
echo "${PACKAGE_KEY}_VERSION=$NEW_VERSION" >> "$ENV_STORE"

echo "✅ Recorded version in $ENV_STORE: ${PACKAGE_KEY}_VERSION=$NEW_VERSION"

echo "🕓 Completed on $(date)"