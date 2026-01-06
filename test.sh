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
# Set S3_ENDPOINT to localhost:4566 for local development (proxy to QA LocalStack)
export S3_ENDPOINT="${S3_ENDPOINT:-http://localhost:4566}"
# Exit code 5 from pytest means "no tests found" - treat as success
uv run pytest "$TEST_DIRECTORY" || {
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 5 ]; then
    echo "⚠️  No tests found in $TEST_DIRECTORY (exit code 5) - treating as success"
    exit 0
  else
    exit $EXIT_CODE
  fi
}
