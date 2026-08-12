#!/usr/bin/env bash
set -euo pipefail
_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_SCRIPTS_DIR/../env.sh"
source "$_SCRIPTS_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

log_info "📦 Building Rust crate..."

# 📁 Required paths
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
CARGO_TOML="${CARGO_TOML:-$PROJECT_ROOT/Cargo.toml}"
TARGET_DIR="${TARGET_DIR:-$PROJECT_ROOT/target}"

# Check if we're in a Rust project
if [[ ! -f "$CARGO_TOML" ]]; then
  log_error "❌ Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

log_info "📁 Working from: $PROJECT_ROOT"

# 🔍 Extract package name from Cargo.toml
PACKAGE_LINE=$(grep -E '^\s*name\s*=' "$CARGO_TOML" | head -n1)
PACKAGE_NAME=$(echo "$PACKAGE_LINE" | awk -F '=' '{gsub(/"/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

if [[ -z "$PACKAGE_NAME" ]]; then
  log_error "❌ Could not extract package name from $CARGO_TOML"
  exit 1
fi

log_info "🔍 Package name: $PACKAGE_NAME"

# 🔍 Get current version from Cargo.toml
VERSION_LINE=$(grep -E '^\s*version\s*=' "$CARGO_TOML" | head -n1)
CURRENT_VERSION=$(echo "$VERSION_LINE" | awk -F '=' '{gsub(/"/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

if [[ -z "$CURRENT_VERSION" ]]; then
  log_error "❌ Could not extract version from $CARGO_TOML"
  exit 1
fi

log_info "🔢 Current version: $CURRENT_VERSION"

# 🧹 Clean old builds
log_info "🧹 Cleaning old artifacts..."
rm -rf "$TARGET_DIR/package" "$TARGET_DIR/dist"

# 🛠️ Build crate package
log_info "📦 Building crate package with cargo..."
cargo package --allow-dirty

# ✅ Confirm output
CRATE_FILE=$(find "$TARGET_DIR/package" -name "${PACKAGE_NAME}-${CURRENT_VERSION}.crate" | head -n1)
if [[ -z "$CRATE_FILE" ]]; then
  log_error "❌ No .crate file found for package '$PACKAGE_NAME'"
  exit 1
fi

log_info "✅ Built: $(basename "$CRATE_FILE")"

# 📁 Create dist directory and copy crate
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"
mkdir -p "$DIST_DIR"
cp "$CRATE_FILE" "$DIST_DIR/"

log_info "📁 Crate copied to: $DIST_DIR/$(basename "$CRATE_FILE")"

# 🚀 Optionally publish to crates.io (if configured)
if [[ "${PUBLISH_CRATE:-false}" == "true" ]]; then
  log_info "📤 Publishing to crates.io..."
  cargo publish --allow-dirty || {
    log_error "❌ Publish failed"
    exit 1
  }
  log_info "✅ Publish complete for $PACKAGE_NAME@$CURRENT_VERSION"
else
  log_info "💡 To publish to crates.io, set PUBLISH_CRATE=true"
fi

log_info "🕓 Finished at $(date)"
