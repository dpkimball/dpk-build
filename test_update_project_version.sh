#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update_pyproject_version.sh"
GET_LATEST_SCRIPT="$SCRIPT_DIR/get_latest_pypi_version.sh"

EXAMPLE="$SCRIPT_DIR/pyproject.example.toml"
TARGET="$SCRIPT_DIR/pyproject.toml"

cp "$EXAMPLE" "$TARGET"

echo "✅ Copied example TOML"
echo "🔍 Before update:"
grep -E "$PACKAGE_NAME|^version =" "$TARGET"

LATEST_VERSION="$("$GET_LATEST_SCRIPT" "$PACKAGE_NAME")"
echo "✅ Latest version on PyPI for $PACKAGE_NAME: $LATEST_VERSION"

"$UPDATE_SCRIPT" "$PACKAGE_NAME" "$TARGET"

echo "🔍 After update:"
grep -E "$PACKAGE_NAME|^version =" "$TARGET"

echo "✅ Done."
