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

if [[ ! -f "Cargo.toml" ]]; then
  log_error "Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

log_step "Running cargo clippy..."
cargo clippy --all-targets --all-features -- -D warnings || {
  log_error "Lint failed — fix clippy warnings above"
  exit 1
}
log_success "Lint passed"
