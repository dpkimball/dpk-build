#!/usr/bin/env bash

source "$KEEPSAKE_SCRIPTS_ROOT/env.sh"

set -euo pipefail
# 🧾 Usage: ./get_latest_pypi_version.sh <package-name>
# Outputs: version string like 0.1.24

PACKAGE_NAME="$1"

PYPI_HOST="${PYPI_HOST:-192.168.86.23}"
PYPI_PORT="${PYPI_PORT:-8080}"
PYPI_USERNAME="${PYPI_USERNAME:-admin}"
PYPI_PASSWORD="${PYPI_PASSWORD:-your-secret-password}"

# 🧽 Normalize: match underscores in filenames
PACKAGE_NAME_SAFE=$(echo "$PACKAGE_NAME" | tr '-' '_')

# 🕸 Fetch the latest matching wheel
WHEEL=$(curl -s -u "$PYPI_USERNAME:$PYPI_PASSWORD" \
  "http://$PYPI_HOST:$PYPI_PORT/simple/$PACKAGE_NAME/" \
  | grep -oE "$PACKAGE_NAME_SAFE-[0-9]+\.[0-9]+\.[0-9]+[^\" ]*\.whl" \
  | sort -V | tail -n1)

# 🧪 Extract version from filename
VERSION=$(basename "$WHEEL" | sed -E "s/^$PACKAGE_NAME_SAFE-([0-9]+\.[0-9]+\.[0-9]+).*\.whl/\1/")

if [[ -z "$VERSION" ]]; then
  echo "❌ Failed to retrieve version for $PACKAGE_NAME" >&2
  exit 1
fi

echo "$VERSION"
