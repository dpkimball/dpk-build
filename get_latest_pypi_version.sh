#!/usr/bin/env bash

source "$KEEPSAKE_SCRIPTS_ROOT/env.sh"

set -euo pipefail
# 🧾 Usage: ./get_latest_pypi_version.sh <package-name>
# Outputs: version string like 0.1.24

PACKAGE_NAME="$1"

# Use environment variables from env.sh (no hardcoded defaults for local development)

# 🔧 Override PyPI settings for local development if set
if [[ -n "${PYPI_HOST_OVERRIDE:-}" ]]; then
  export PYPI_HOST="$PYPI_HOST_OVERRIDE"
fi
if [[ -n "${PYPI_PORT_OVERRIDE:-}" ]]; then
  export PYPI_PORT="$PYPI_PORT_OVERRIDE"
fi

# 🧽 Normalize: match underscores in filenames
PACKAGE_NAME_SAFE=$(echo "$PACKAGE_NAME" | tr '-' '_')

# 🕸 Fetch the latest matching wheel
WHEEL=$(curl -s -u "$PYPI_USERNAME:$PYPI_PASSWORD" \
  "http://$PYPI_HOST:$PYPI_PORT/simple/$PACKAGE_NAME/" \
  | grep -oE "$PACKAGE_NAME_SAFE-[0-9]+\.[0-9]+\.[0-9]+[^\" ]*\.whl" \
  | sort -V | tail -n1 || true)

# 🧪 Extract version from filename
VERSION=$(basename "$WHEEL" | sed -E "s/^$PACKAGE_NAME_SAFE-([0-9]+\.[0-9]+\.[0-9]+).*\.whl/\1/" || true)

if [[ -z "$VERSION" ]]; then
  # No versions found - return empty string to indicate first build
  echo ""
  exit 0
fi

echo "$VERSION"
