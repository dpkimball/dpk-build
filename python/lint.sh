#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

if [[ "${SKIP_LINT:-false}" == "true" ]]; then
  log_warning "Skipping lint..."
  exit 0
fi

LINT_DIRECTORY="${LINT_DIRECTORY:-.}"

log_step "Running ruff..."
uv run ruff check "$LINT_DIRECTORY" || {
  log_error "Lint failed — run 'uv run ruff check --fix' to auto-fix"
  exit 1
}
uv run ruff format "$LINT_DIRECTORY" --check || {
  log_error "Format issues — run 'uv run ruff format' to fix"
  exit 1
}
log_success "Lint passed"
