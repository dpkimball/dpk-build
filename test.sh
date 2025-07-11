#!/bin/bash
set -euo pipefail

# Optionally set this before calling the script: SKIP_TESTS=true
if [[ "${SKIP_TESTS:-false}" == "true" ]]; then
  echo "⚠️ Skipping tests..."
  exit 0
fi

# Allow configurable test directory, defaulting to "tests"
TEST_DIRECTORY="${TEST_DIRECTORY:-tests}"

echo "✔ 🧪 Running tests in '$TEST_DIRECTORY'..."
uv run pytest "$TEST_DIRECTORY"
