#!/bin/bash
set -euo pipefail
_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_SCRIPTS_DIR/../env.sh"
source "$_SCRIPTS_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

if [[ "${SKIP_TESTS:-false}" == "true" ]]; then
  log_warning "Skipping tests..."
  exit 0
fi

if [[ ! -f "Cargo.toml" ]]; then
  log_error "Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

log_info "🧪 Running cargo test..."
cargo test --all || {
  log_error "Tests failed"
  exit 1
}
log_success "Tests passed"
