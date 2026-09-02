#!/usr/bin/env bash
set -euo pipefail
_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_SCRIPTS_DIR/env.sh"
source "$_SCRIPTS_DIR/common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

PYPROJECT="${PYPROJECT:-$PWD/pyproject.toml}"

if [[ ! -f "$PYPROJECT" ]]; then
  log_error "pyproject.toml not found at $PYPROJECT"
  exit 1
fi

if [[ -z "${INTERNAL_PKGS:-}" ]]; then
  log_info "No INTERNAL_PKGS defined — nothing to update"
  exit 0
fi

log_step "Updating internal package versions in $PYPROJECT..."

for pkg in $INTERNAL_PKGS; do
  log_info "  → $pkg"
  "$_SCRIPTS_DIR/python/update_pyproject_version.sh" "$pkg" "$PYPROJECT"
done

log_success "Version update complete"
