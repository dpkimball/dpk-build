#!/usr/bin/env bash
# Project env.sh must not clobber the phase script's directory.
# python/build.sh already uses _SCRIPTS_DIR; the other phase scripts must match.
#
# Usage: bash tests/shell/script-dir-survives-project-env.sh
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

# --- contract: scripts that source $PWD/env.sh must not keep SCRIPT_DIR as
#     their own path after that source (consumers commonly set SCRIPT_DIR).
while IFS= read -r f; do
  rel="${f#"$REPO_ROOT"/}"
  if grep -q '\[ -f "$PWD/env.sh" \] && source "$PWD/env.sh"' "$f"; then
    if grep -q '^SCRIPT_DIR=' "$f"; then
      fail "no-script-dir-after-project-env:$rel" \
        "uses SCRIPT_DIR; source \$PWD/env.sh can clobber it (use _SCRIPTS_DIR)"
    else
      pass "no-script-dir-after-project-env:$rel"
    fi
    if grep -q '^_SCRIPTS_DIR=' "$f"; then
      pass "uses-scripts-dir:$rel"
    else
      fail "uses-scripts-dir:$rel" "expected _SCRIPTS_DIR like python/build.sh"
    fi
  fi
done < <(find "$REPO_ROOT/python" "$REPO_ROOT/rust" -name '*.sh' | sort)

# --- hermetic: env.sh sets SCRIPT_DIR to garbage; detect-cluster still resolves
#     under dpk-build, not under the decoy path.
probe_deploy() {
  local script="$1"
  local name="$2"
  local tmp
  tmp="$(mktemp -d)"
  cat >"$tmp/env.sh" <<'EOF'
SCRIPT_DIR=/definitely/wrong/script-dir
export SCRIPT_DIR
EOF
  local out
  if ! out="$(cd "$tmp" && DPK_SCRIPT_DIR_PROBE=1 bash "$script" 2>/dev/null)"; then
    fail "$name" "probe exited nonzero"
    rm -rf "$tmp"
    return
  fi
  local scripts_dir detect
  scripts_dir="$(printf '%s\n' "$out" | awk -F= '/^probe_scripts_dir=/{print substr($0,19)}')"
  detect="$(printf '%s\n' "$out" | awk -F= '/^probe_detect=/{print substr($0,14)}')"
  if [[ "$scripts_dir" == "$REPO_ROOT/"* ]]; then
    pass "$name/scripts-dir-under-dpk-build"
  else
    fail "$name/scripts-dir-under-dpk-build" "got '$scripts_dir'"
  fi
  if [[ "$detect" == "$REPO_ROOT/shared/detect-cluster.sh" ]] || [[ "$detect" == "$REPO_ROOT/"*/shared/detect-cluster.sh ]]; then
    pass "$name/detect-under-dpk-build"
  else
    fail "$name/detect-under-dpk-build" "got '$detect'"
  fi
  if printf '%s\n' "$out" | grep -q '/definitely/wrong'; then
    fail "$name/no-decoy-path" "decoy SCRIPT_DIR leaked into probe output"
  else
    pass "$name/no-decoy-path"
  fi
  rm -rf "$tmp"
}

probe_deploy "$REPO_ROOT/python/deploy-k8s.sh" "python-deploy"
probe_deploy "$REPO_ROOT/rust/deploy-k8s.sh" "rust-deploy"

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
