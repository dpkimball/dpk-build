#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

log_info "🦀 Building Rust project..."

if [[ ! -f "Cargo.toml" ]]; then
  log_error "Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

if [[ "${1:-}" == "--clean" ]]; then
  log_info "🧹 Cleaning previous build artifacts..."
  cargo clean
fi

log_info "🔨 Building Rust project..."
cargo build --release

if [[ "${SKIP_LINT:-false}" != "true" ]]; then
  log_info "🔍 Running Rust linting..."
  cargo clippy --all-targets --all-features -- -D warnings
fi

if [[ "${SKIP_TESTS:-false}" != "true" ]]; then
  log_info "🧪 Running Rust tests..."
  cargo test
fi

if [[ "${SKIP_CRATE:-false}" != "true" ]]; then
  log_info "📦 Building Rust crate..."
  "$SCRIPT_DIR/build-crate.sh"
fi

if [[ "${SKIP_DOCKER_IMAGE:-false}" != "true" ]]; then
  log_info "🐳 Building Docker image..."
  "$SCRIPT_DIR/build-docker.sh"
fi

log_success "✅ Rust build complete!"
