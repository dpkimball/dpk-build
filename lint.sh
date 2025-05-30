#!/bin/bash

set -euo pipefail
source "$(dirname "$0")/common.sh"

print_status "🧹 Running linters..."
npx biome check . || print_warning "⚠ Linting issues found"
