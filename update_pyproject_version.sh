#!/usr/bin/env bash
set -euo pipefail

# 🧾 Usage: ./update_pyproject_version.sh <package-name> <pyproject-path>
# Example: ./update_pyproject_version.sh keepsake_services ./pyproject.toml

PACKAGE_NAME="$1"
PYPROJECT_FILE="$2"

# Optional: override PyPI host/port via env
PYPI_HOST="${PYPI_HOST:-192.168.86.23}"
PYPI_PORT="${PYPI_PORT:-8080}"
PYPI_USERNAME="${PYPI_USERNAME:-admin}"
PYPI_PASSWORD="${PYPI_PASSWORD:-your-secret-password}"

echo "📦 Fetching latest version of $PACKAGE_NAME from PyPI at $PYPI_HOST:$PYPI_PORT..."

# 🔍 Get latest version from local PyPI server
LATEST_WHEEL=$(curl -s -u "$PYPI_USERNAME:$PYPI_PASSWORD" \
  "http://$PYPI_HOST:$PYPI_PORT/simple/$PACKAGE_NAME/" \
  | grep -oE "$PACKAGE_NAME-[0-9]+\.[0-9]+\.[0-9]+.*\.whl" \
  | sort -V | tail -n1)

LATEST_VERSION=$(basename "$LATEST_WHEEL" | sed -E 's/^.*-([0-9]+\.[0-9]+\.[0-9]+)-.*$/\1/')

if [[ -z "$LATEST_VERSION" ]]; then
  echo "❌ Could not retrieve version for $PACKAGE_NAME"
  exit 1
fi

echo "✅ Found latest version: $LATEST_VERSION"

# 🛠️ Update pyproject.toml
ESCAPED_NAME=$(echo "$PACKAGE_NAME" | sed 's/-/_/g')

# macOS vs Linux `sed` compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' -E "s/($ESCAPED_NAME\s*=\s*\")[^\"]+\"/\1==$LATEST_VERSION\"/" "$PYPROJECT_FILE"
else
  sed -i -E "s/($ESCAPED_NAME\s*=\s*\")[^\"]+\"/\1==$LATEST_VERSION\"/" "$PYPROJECT_FILE"
fi

echo "📝 Updated $PACKAGE_NAME version to ==$LATEST_VERSION in $PYPROJECT_FILE"
