#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
(cd "$SCRIPT_DIR" && cargo build --release --quiet) >&2
echo "$SCRIPT_DIR/target/release/dpk-build"
