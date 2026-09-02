#!/usr/bin/env bash
# Behaviour matrix for the canonical path contract: paths.sh and the root env.sh.
# Owned by CI — see .github/workflows/shellcheck.yml.
#
# Usage: bash tests/shell/paths-env-matrix.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASSED=0
FAILED=0

pass() {
  printf 'PASS %s\n' "$1"
  PASSED=$((PASSED + 1))
}

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
  FAILED=$((FAILED + 1))
}

assert_eq() { # name expected actual
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1" "expected '$2', got '$3'"
  fi
}

assert_nonempty() { # name value
  if [ -n "$2" ]; then
    pass "$1"
  else
    fail "$1" "value is empty"
  fi
}

# Source paths.sh in a clean child environment.
probe_paths() {
  env -u SSD -u WORKSPACE_ROOT -u BUILD_ROOT \
    "$@" bash -c '
      set -eu
      cd "$1"
      # shellcheck source=/dev/null
      . ./paths.sh
      printf "%s\t%s\t%s\n" "$SSD" "$WORKSPACE_ROOT" "$BUILD_ROOT"
    ' _ "$REPO_ROOT"
}

new_tmpdir() {
  local dir
  dir="$(mktemp -d)"
  (cd "$dir" && pwd)
}

# --- paths.sh: defaults -------------------------------------------------------

read -r ssd workspace build_root <<<"$(probe_paths)"
assert_eq "paths/default_ssd_constant" "/Volumes/SSD" "$ssd"

empty_ssd="$(new_tmpdir)"
read -r ssd workspace build_root <<<"$(probe_paths SSD="$empty_ssd")"
assert_eq "paths/default_workspace_dir_is_dpk_workspace" \
  "$empty_ssd/dpk-workspace" "$workspace"
assert_eq "paths/build_root_defaults_under_workspace" \
  "$empty_ssd/dpk-workspace/dpk-build" "$build_root"
rm -rf "$empty_ssd"

# --- paths.sh: overrides ------------------------------------------------------

custom_ssd="$(new_tmpdir)"
read -r ssd workspace build_root <<<"$(probe_paths \
  SSD="$custom_ssd" \
  WORKSPACE_ROOT="$custom_ssd/my-workspace" \
  BUILD_ROOT="$custom_ssd/my-workspace/dpk-build")"
assert_eq "paths/explicit_workspace_root_honoured" "$custom_ssd/my-workspace" "$workspace"
assert_eq "paths/explicit_build_root_honoured" "$custom_ssd/my-workspace/dpk-build" "$build_root"
rm -rf "$custom_ssd"

# --- repository shape ---------------------------------------------------------

if [ -e "$REPO_ROOT/keepsake-paths.sh" ]; then
  fail "repo/no_legacy_paths_file" "keepsake-paths.sh still exists"
else
  pass "repo/no_legacy_paths_file"
fi

# No tracked shell script should contain legacy KEEPSAKE_* variable names.
# The matrix itself is excluded because the grep pattern string appears here.
offenders="$(git -C "$REPO_ROOT" ls-files '*.sh' \
  | grep -v '^tests/shell/paths-env-matrix\.sh$' \
  | (cd "$REPO_ROOT" && xargs grep -lE 'KEEPSAKE_') 2>/dev/null || true)"
if [ -n "$offenders" ]; then
  fail "repo/no_keepsake_vars_in_shell" \
    "KEEPSAKE_* variable found in: $(echo "$offenders" | tr '\n' ' ')"
else
  pass "repo/no_keepsake_vars_in_shell"
fi

# --- env.sh -------------------------------------------------------------------

env_probe="$(env -u SSD -u WORKSPACE_ROOT \
  BUILD_ROOT=/nonexistent/wrong bash -c '
    set -eu
    cd "$1"
    # shellcheck source=/dev/null
    . ./env.sh
    printf "%s\t%s\n" "$BUILD_ROOT" "${DPK_PYPI_PORT:-}"
  ' _ "$REPO_ROOT")"
read -r sourced_build_root pypi_port <<<"$env_probe"
assert_eq "env/forces_build_root_to_own_directory" "$REPO_ROOT" "$sourced_build_root"
assert_nonempty "env/exports_dpk_pypi_port" "$pypi_port"

# --- summary ------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
