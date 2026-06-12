#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

# 🔧 Store PyPI settings for local development if set (don't export yet)
if [[ -n "${PYPI_HOST_OVERRIDE:-}" ]]; then
  PYPI_HOST="$PYPI_HOST_OVERRIDE"
else
  PYPI_HOST="${PYPI_HOST:-localhost}"
fi
if [[ -n "${PYPI_PORT_OVERRIDE:-}" ]]; then
  PYPI_PORT="$PYPI_PORT_OVERRIDE"
else
  PYPI_PORT="${PYPI_PORT:-31126}"
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
GET_VERSION_SCRIPT="$SCRIPT_DIR/../shared/get_latest_pypi_version.sh"

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
  if [[ "${FIRST_BUILD:-}" == "1" ]]; then
    log_info "⚠️  No versions found on PyPI. FIRST_BUILD=1 set — starting at 0.0.1"
    LATEST_VERSION="0.0.0"
  else
    log_error "❌ No versions found on PyPI for '$PACKAGE_NAME'."
    log_error "   If this is a first build, set FIRST_BUILD=1 and re-run."
    log_error "   If PyPI is unreachable, check PYPI_HOST ($PYPI_HOST) and PYPI_PORT ($PYPI_PORT)."
    exit 1
  fi
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
# Install build dependencies for Python 3.12+ (setuptools, poetry-core, maturin)
# These are needed when building with --no-build-isolation for packages like pendulum
PYTHON_MAJOR_MINOR=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
USE_NO_BUILD_ISOLATION=""
if [[ -n "$PYTHON_MAJOR_MINOR" ]]; then
  PYTHON_MAJOR=$(echo "$PYTHON_MAJOR_MINOR" | cut -d. -f1)
  PYTHON_MINOR=$(echo "$PYTHON_MAJOR_MINOR" | cut -d. -f2)
    if [[ "$PYTHON_MAJOR" -ge 3 ]] && [[ "$PYTHON_MINOR" -ge 12 ]]; then
      log_info "🔧 Installing build dependencies for Python 3.12+..."
      if [[ -n "${UV_INDEX_URL:-}" ]]; then
        if [[ -n "${UV_EXTRA_INDEX_URL:-}" ]]; then
          uv pip install --default-index "$UV_INDEX_URL" --index "$UV_EXTRA_INDEX_URL" --index-strategy unsafe-best-match "setuptools>=65.0.0" poetry-core maturin "hatchling>=1.24" || true
        else
          uv pip install --default-index "$UV_INDEX_URL" --index-strategy unsafe-best-match "setuptools>=65.0.0" poetry-core maturin "hatchling>=1.24" || true
        fi
      else
        uv pip install "setuptools>=65.0.0" poetry-core maturin "hatchling>=1.24" || true
      fi
      USE_NO_BUILD_ISOLATION="--no-build-isolation"
    fi
fi
# Build with uv - PyPI env vars should be correct now
# Use unsafe-best-match to allow checking all indexes when package exists on public PyPI but has no versions
# Use --no-build-isolation for Python 3.12+ so build dependencies are available
if [[ -n "${UV_INDEX_URL:-}" ]]; then
  if [[ -n "${UV_EXTRA_INDEX_URL:-}" ]]; then
    uv build --default-index "$UV_INDEX_URL" --index "$UV_EXTRA_INDEX_URL" --index-strategy unsafe-best-match $USE_NO_BUILD_ISOLATION
  else
    uv build --default-index "$UV_INDEX_URL" --index-strategy unsafe-best-match $USE_NO_BUILD_ISOLATION
  fi
else
  uv build $USE_NO_BUILD_ISOLATION
fi

# ✅ Confirm output
PACKAGE_NAME_UNDERSCORE="${PACKAGE_NAME//-/_}"
PACKAGE_NAME_LOWER=$(echo "$PACKAGE_NAME_UNDERSCORE" | tr '[:upper:]' '[:lower:]')
WHEEL_FILE=$(find "$DIST_DIR" -name "${PACKAGE_NAME_LOWER}-*.whl" | head -n1)
if [[ -z "$WHEEL_FILE" ]]; then
  log_error "❌ No .whl file found for package '$PACKAGE_NAME'"
  exit 1
fi

log_info "✅ Built: $(basename "$WHEEL_FILE")"

# 🚀 Upload to local PyPI
log_info "📤 Uploading to PyPI ($PYPI_HOST:$PYPI_PORT)..."
# twine should be installed via project dev-dependencies, but install it if missing
uv pip install twine >/dev/null 2>&1 || pip install twine >/dev/null 2>&1 || true
set +e  # Temporarily disable exit on error to capture exit code
UPLOAD_OUTPUT=$(twine upload \
  --repository-url "http://$PYPI_HOST:$PYPI_PORT" \
  --username "$PYPI_USERNAME" \
  --password "$PYPI_PASSWORD" \
  "$WHEEL_FILE" 2>&1)
UPLOAD_EXIT=$?
set -e  # Re-enable exit on error

if [ $UPLOAD_EXIT -ne 0 ]; then
    if echo "$UPLOAD_OUTPUT" | grep -qiE "409|Conflict"; then
        log_info "⚠️  Version $NEW_VERSION already exists on PyPI, skipping upload (this is OK)"
    else
        echo "$UPLOAD_OUTPUT" >&2
        log_error "❌ Upload failed"
        exit 1
    fi
else
    echo "$UPLOAD_OUTPUT"
    log_info "✅ Upload complete for $PACKAGE_NAME@$NEW_VERSION"
fi

log_info "🕓 Finished at $(date)"
