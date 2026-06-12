#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

if [[ "${SKIP_TESTS:-false}" == "true" ]]; then
  log_warning "Skipping tests..."
  exit 0
fi

TEST_DIRECTORY="${TEST_DIRECTORY:-tests}"

log_info "🧪 Running tests in '$TEST_DIRECTORY'..."
export S3_ENDPOINT="${S3_ENDPOINT:-http://localhost:4566}"
uv run python -m pytest "$TEST_DIRECTORY" || {
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 5 ]; then
    log_warning "No tests found in $TEST_DIRECTORY (exit code 5) - treating as success"
    exit 0
  else
    exit $EXIT_CODE
  fi
}
