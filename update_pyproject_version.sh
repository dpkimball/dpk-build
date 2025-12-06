#!/usr/bin/env bash
set -euo pipefail

# 🧾 Usage: ./update_pyproject_version.sh <package-name> <pyproject-path>

PACKAGE_NAME="$1"
PYPROJECT_FILE="$2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GET_VERSION_SCRIPT="$SCRIPT_DIR/get_latest_pypi_version.sh"

LATEST_VERSION="$("$GET_VERSION_SCRIPT" "$PACKAGE_NAME")"

echo "✅ Found latest version: $LATEST_VERSION"

# 🛠️ Update pyproject.toml (supports both list-style and table-style)
ESCAPED_NAME=$(echo "$PACKAGE_NAME" | sed 's/-/_/g')

# macOS vs Linux `sed` compatibility
ESCAPED_NAME=$(echo "$PACKAGE_NAME" | sed 's/[]\/$*.^[]/\\&/g')

# Replace "name==<version>", "name>=<version>", or "name~=<version>" inside dependencies block
# Check if package exists in file first
if grep -q "\"${PACKAGE_NAME}" "$PYPROJECT_FILE"; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' -E "s/(\"${ESCAPED_NAME}(\[[^]]+\\])?[>=~=]+)[^\"]*\"/\1${LATEST_VERSION}\"/" "$PYPROJECT_FILE"
  else
    sed -i -E "s/(\"${ESCAPED_NAME}(\[[^]]+\\])?[>=~=]+)[^\"]*\"/\1${LATEST_VERSION}\"/" "$PYPROJECT_FILE"
  fi
  echo "📝 Updated $PACKAGE_NAME version to >=${LATEST_VERSION} in $PYPROJECT_FILE"
else
  echo "⚠️  $PACKAGE_NAME not found in dependencies, skipping update"
fi
