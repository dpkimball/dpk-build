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

# Source paths.sh in a child with a clean path environment. Extra KEY=VALUE
# arguments are exported for that child only.
probe_paths() {
  env -u SSD -u WORKSPACE_ROOT -u BUILD_ROOT \
    -u KEEPSAKE_SSD -u KEEPSAKE_PROJECT_ROOT -u KEEPSAKE_SCRIPTS_ROOT \
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
assert_eq "paths/default_ssd_constant" "/Volumes/KeepsakeSSD" "$ssd"

empty_ssd="$(new_tmpdir)"
read -r ssd workspace build_root <<<"$(probe_paths SSD="$empty_ssd")"
assert_eq "paths/default_workspace_dir_is_dpk_workspace" \
  "$empty_ssd/dpk-workspace" "$workspace"
assert_eq "paths/build_root_defaults_under_workspace" \
  "$empty_ssd/dpk-workspace/dpk-build" "$build_root"
rm -rf "$empty_ssd"

# --- paths.sh: workspace directory discovery ---------------------------------

both_ssd="$(new_tmpdir)"
mkdir -p "$both_ssd/dpk-workspace" "$both_ssd/keepsake-workspace"
read -r ssd workspace build_root <<<"$(probe_paths SSD="$both_ssd")"
assert_eq "paths/prefers_dpk_workspace_when_both_present" \
  "$both_ssd/dpk-workspace" "$workspace"
rm -rf "$both_ssd"

legacy_ssd="$(new_tmpdir)"
mkdir -p "$legacy_ssd/keepsake-workspace"
read -r ssd workspace build_root <<<"$(probe_paths SSD="$legacy_ssd")"
assert_eq "paths/discovers_legacy_workspace_dir" \
  "$legacy_ssd/keepsake-workspace" "$workspace"
rm -rf "$legacy_ssd"

# --- paths.sh: legacy KEEPSAKE_* inputs are read-only fallbacks ---------------

read -r ssd workspace build_root <<<"$(probe_paths \
  KEEPSAKE_SSD=/legacy/ssd \
  KEEPSAKE_PROJECT_ROOT=/legacy/workspace \
  KEEPSAKE_SCRIPTS_ROOT=/legacy/workspace/dpk-build)"
assert_eq "paths/legacy_ssd_input_maps_to_ssd" "/legacy/ssd" "$ssd"
assert_eq "paths/legacy_project_root_input_maps_to_workspace_root" \
  "/legacy/workspace" "$workspace"
assert_eq "paths/legacy_scripts_root_input_maps_to_build_root" \
  "/legacy/workspace/dpk-build" "$build_root"

read -r ssd workspace build_root <<<"$(probe_paths \
  SSD=/canonical/ssd \
  WORKSPACE_ROOT=/canonical/workspace \
  BUILD_ROOT=/canonical/workspace/dpk-build \
  KEEPSAKE_SSD=/legacy/ssd \
  KEEPSAKE_PROJECT_ROOT=/legacy/workspace \
  KEEPSAKE_SCRIPTS_ROOT=/legacy/workspace/dpk-build)"
assert_eq "paths/canonical_ssd_wins_over_legacy" "/canonical/ssd" "$ssd"
assert_eq "paths/canonical_workspace_root_wins_over_legacy" \
  "/canonical/workspace" "$workspace"
assert_eq "paths/canonical_build_root_wins_over_legacy" \
  "/canonical/workspace/dpk-build" "$build_root"

if grep -Eq '^[[:space:]]*export[[:space:]]+KEEPSAKE_' "$REPO_ROOT/paths.sh"; then
  fail "paths/no_legacy_path_exports" "paths.sh exports a KEEPSAKE_* path name"
else
  pass "paths/no_legacy_path_exports"
fi

# --- repository shape ---------------------------------------------------------

# Tracked shell scripts, excluding the two files that legitimately mention the
# legacy names: paths.sh (read fallbacks) and this matrix (which asserts them).
tracked_scripts() {
  git -C "$REPO_ROOT" ls-files '*.sh' \
    | grep -v -e '^paths\.sh$' -e '^tests/shell/paths-env-matrix\.sh$'
}

if [ -e "$REPO_ROOT/keepsake-paths.sh" ]; then
  fail "repo/no_legacy_paths_file" "keepsake-paths.sh still exists"
else
  pass "repo/no_legacy_paths_file"
fi

offenders="$(tracked_scripts \
  | (cd "$REPO_ROOT" && xargs grep -lE 'KEEPSAKE_(SSD|PROJECT_ROOT|SCRIPTS_ROOT)') || true)"
if [ -n "$offenders" ]; then
  fail "repo/legacy_path_aliases_confined_to_paths_sh" \
    "legacy path aliases used outside paths.sh: $(echo "$offenders" | tr '\n' ' ')"
else
  pass "repo/legacy_path_aliases_confined_to_paths_sh"
fi

offenders="$(tracked_scripts \
  | (cd "$REPO_ROOT" && xargs grep -l 'keepsake-workspace') || true)"
if [ -n "$offenders" ]; then
  fail "repo/umbrella_name_confined_to_paths_sh" \
    "umbrella folder name hardcoded outside paths.sh: $(echo "$offenders" | tr '\n' ' ')"
else
  pass "repo/umbrella_name_confined_to_paths_sh"
fi

# --- env.sh -------------------------------------------------------------------

env_probe="$(env -u SSD -u WORKSPACE_ROOT -u KEEPSAKE_SSD \
  -u KEEPSAKE_PROJECT_ROOT -u KEEPSAKE_SCRIPTS_ROOT \
  BUILD_ROOT=/nonexistent/wrong bash -c '
    set -eu
    cd "$1"
    # shellcheck source=/dev/null
    . ./env.sh
    printf "%s\t%s\n" "$BUILD_ROOT" "${KEEPSAKE_BACKEND_PORT:-}"
  ' _ "$REPO_ROOT")"
read -r sourced_build_root backend_port <<<"$env_probe"
assert_eq "env/forces_build_root_to_own_directory" "$REPO_ROOT" "$sourced_build_root"
assert_nonempty "env/keeps_keepsake_port_names_out_of_scope" "$backend_port"

# --- summary ------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
