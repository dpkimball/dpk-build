#!/bin/bash
set -euo pipefail
if [[ "${SKIP_TESTS:-false}" == "true" ]]; then
  echo "⚠️ Skipping tests..."
  exit 0
fi

echo "✔ 🧪 Running tests..."
uv run pytest "$TEST_DIRECTORY"
