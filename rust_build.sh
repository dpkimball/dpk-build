#!/bin/bash
set -euo pipefail

# Load shared env defaults (assumes sourced by outer wrapper like bin/build.sh)
# This should already be done before calling this script
# source "$KEEPSAKE_SCRIPTS_ROOT/env.sh"
source "$KEEPSAKE_SCRIPTS_ROOT/utils.sh"

log_info "🦀 Building Rust project..."

# Check if we're in a Rust project
if [[ ! -f "Cargo.toml" ]]; then
  log_error "Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

# Clean build if requested
if [[ "${1:-}" == "--clean" ]]; then
  log_info "🧹 Cleaning previous build artifacts..."
  cargo clean
fi

log_info "🔨 Building Rust project..."
cargo build --release

# ✅ Modular and conditional execution
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
  "$KEEPSAKE_SCRIPTS_ROOT/rust_build_crate.sh"
fi

if [[ "${SKIP_DOCKER_IMAGE:-false}" != "true" ]]; then
  log_info "🐳 Building Docker image..."
  "$KEEPSAKE_SCRIPTS_ROOT/rust_docker_build.sh"
fi

log_success "✅ Rust build complete!"
