#!/usr/bin/env bash
# Dry-run deliver + deploy preamble probe against every sibling dpk.toml.
# Skips (exit 0) when this checkout is not inside a dpk-workspace tree —
# GitHub CI for dpk-build only has this repo.
#
# Usage: bash tests/shell/workspace-consumer-dry-run.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE="$(cd "$REPO_ROOT/.." && pwd)"

if [ ! -f "$WORKSPACE/dpk-workspace.toml" ]; then
  printf 'SKIP workspace-consumer-dry-run: no %s/dpk-workspace.toml\n' "$WORKSPACE"
  exit 0
fi

BIN="$REPO_ROOT/target/debug/dpk-build"
if [ ! -x "$BIN" ]; then
  (cd "$REPO_ROOT" && cargo build --quiet)
fi

PASSED=0
FAILED=0
pass() { printf 'PASS %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; FAILED=$((FAILED + 1)); }

language_of() {
  python3 -c '
import sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib
with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
print((data.get("project") or {}).get("language") or "")
' "$1"
}

deploy_script_for() {
  case "$1" in
    rust) printf '%s\n' "$REPO_ROOT/rust/deploy-k8s.sh" ;;
    *) printf '%s\n' "$REPO_ROOT/python/deploy-k8s.sh" ;;
  esac
}

TOMLS=()
while IFS= read -r toml; do
  TOMLS+=("$toml")
done < <(
  find "$WORKSPACE" -name dpk.toml \
    ! -path '*/target/*' \
    ! -path '*/node_modules/*' \
    ! -path '*/.git/*' \
    ! -path '*/.claude/*' \
    ! -path "$REPO_ROOT/tests/*" \
    | sort
)

if [ "${#TOMLS[@]}" -eq 0 ]; then
  fail "found-consumers" "no dpk.toml under $WORKSPACE"
  printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
  exit 1
fi
pass "found-consumers:${#TOMLS[@]}"

for toml in "${TOMLS[@]}"; do
  dir="$(dirname "$toml")"
  rel="${dir#"$WORKSPACE"/}"
  lang="$(language_of "$toml")"
  lang="${lang:-unknown}"

  out=""
  code=0
  set +e
  out="$(
    cd "$dir" && BUILD_ROOT="$REPO_ROOT" "$BIN" --dry-run deliver 2>/dev/null
  )"
  code=$?
  set -e
  json="$(printf '%s\n' "$out" | awk 'BEGIN{p=0} /^\{/{p=1} p{print}' | tail -n 1)"
  status="$(printf '%s\n' "$json" | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("status",""))
except Exception:
    print("")' 2>/dev/null || true)"
  if [ "$code" -eq 0 ] && [ "$status" = "success" ]; then
    pass "dry-run:$rel ($lang)"
  else
    fail "dry-run:$rel ($lang)" "exit=$code status='$status' json='$json'"
  fi

  if [ -f "$dir/env.sh" ]; then
    script="$(deploy_script_for "$lang")"
    probe_out=""
    set +e
    probe_out="$(cd "$dir" && DPK_SCRIPT_DIR_PROBE=1 bash "$script" 2>/dev/null)"
    probe_code=$?
    set -e
    detect="$(printf '%s\n' "$probe_out" | awk -F= '/^probe_detect=/{print substr($0,14)}')"
    if [ "$probe_code" -eq 0 ] && [[ "$detect" == "$REPO_ROOT/"*"/shared/detect-cluster.sh" || "$detect" == "$REPO_ROOT/shared/detect-cluster.sh" ]]; then
      pass "probe:$rel"
    else
      fail "probe:$rel" "exit=$probe_code detect='$detect'"
    fi
  else
    pass "probe:$rel (no env.sh)"
  fi
done

printf '\n%d passed, %d failed (%d consumers)\n' "$PASSED" "$FAILED" "${#TOMLS[@]}"
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
