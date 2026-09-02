#!/usr/bin/env bash
# In-repo consumer contract. Always runs in CI (no sibling-workspace dependency).
#
# Covers the language × image/deploy script matrix and project env.sh that sets
# SCRIPT_DIR (the clobber that used to point detect-cluster.sh at the consumer).
#
# Usage: bash tests/shell/consumer-contract.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/consumers"
BIN="$REPO_ROOT/target/debug/dpk-build"

PASSED=0
FAILED=0
pass() { printf 'PASS %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; FAILED=$((FAILED + 1)); }

if [ ! -x "$BIN" ]; then
  (cd "$REPO_ROOT" && cargo build --quiet)
fi

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

image_script_for() {
  case "$1" in
    rust) printf '%s\n' "$REPO_ROOT/rust/build-docker.sh" ;;
    *) printf '%s\n' "$REPO_ROOT/python/build-docker.sh" ;;
  esac
}

deploy_script_for() {
  case "$1" in
    rust) printf '%s\n' "$REPO_ROOT/rust/deploy-k8s.sh" ;;
    *) printf '%s\n' "$REPO_ROOT/python/deploy-k8s.sh" ;;
  esac
}

json_field() {
  python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    print(""); raise SystemExit(0)
path=sys.argv[1].split(".")
cur=d
for p in path:
    if isinstance(cur, dict):
        cur=cur.get(p)
    else:
        cur=None
        break
print("" if cur is None else cur)
' "$1"
}

CONSUMERS="java_runtime node_frontend python_plain python_script_dir_clobber rust_plain"

for name in $CONSUMERS; do
  dir="$FIXTURES/$name"
  toml="$dir/dpk.toml"
  if [ ! -f "$toml" ]; then
    fail "fixture:$name" "missing $toml"
    continue
  fi
  pass "fixture:$name"
  lang="$(language_of "$toml")"
  lang="${lang:-unknown}"

  out=""
  code=0
  set +e
  out="$(cd "$dir" && BUILD_ROOT="$REPO_ROOT" "$BIN" --dry-run deliver 2>/dev/null)"
  code=$?
  set -e
  json="$(printf '%s\n' "$out" | awk 'BEGIN{p=0} /^\{/{p=1} p{print}' | tail -n 1)"
  status="$(printf '%s\n' "$json" | json_field status)"
  if [ "$code" -eq 0 ] && [ "$status" = "success" ]; then
    pass "dry-run:$name ($lang)"
  else
    fail "dry-run:$name ($lang)" "exit=$code status='$status'"
  fi

  img="$(image_script_for "$lang")"
  img_out=""
  set +e
  img_out="$(cd "$dir" && DPK_IMAGE_SCRIPT_PROBE=1 bash "$img" 2>/dev/null)"
  img_code=$?
  set -e
  scripts_dir="$(printf '%s\n' "$img_out" | awk -F= '/^probe_scripts_dir=/{print substr($0,19)}')"
  if [ "$img_code" -eq 0 ] && [[ "$scripts_dir" == "$REPO_ROOT/"* ]]; then
    pass "image-probe:$name"
  else
    fail "image-probe:$name" "exit=$img_code scripts_dir='$scripts_dir'"
  fi

  dep="$(deploy_script_for "$lang")"
  dep_out=""
  set +e
  dep_out="$(cd "$dir" && DPK_SCRIPT_DIR_PROBE=1 bash "$dep" 2>/dev/null)"
  dep_code=$?
  set -e
  detect="$(printf '%s\n' "$dep_out" | awk -F= '/^probe_detect=/{print substr($0,14)}')"
  if [ "$dep_code" -eq 0 ] && [[ "$detect" == "$REPO_ROOT/"*"/shared/detect-cluster.sh" || "$detect" == "$REPO_ROOT/shared/detect-cluster.sh" ]]; then
    pass "deploy-probe:$name"
  else
    fail "deploy-probe:$name" "exit=$dep_code detect='$detect'"
  fi
  if printf '%s\n' "$dep_out$img_out" | grep -q '/definitely/wrong'; then
    fail "no-decoy:$name" "decoy SCRIPT_DIR leaked into probe output"
  else
    pass "no-decoy:$name"
  fi

  # CLI image phase must invoke the language's docker script (probe exits before docker).
  cli_out=""
  cli_code=0
  set +e
  cli_out="$(
    cd "$dir" && BUILD_ROOT="$REPO_ROOT" DPK_IMAGE_SCRIPT_PROBE=1 \
      "$BIN" deliver --skip-lint --skip-tests --skip-build --skip-deploy 2>/dev/null
  )"
  cli_code=$?
  set -e
  cli_json="$(printf '%s\n' "$cli_out" | awk 'BEGIN{p=0} /^\{/{p=1} p{print}' | tail -n 1)"
  img_status="$(printf '%s\n' "$cli_json" | json_field phases.image.status)"
  img_err="$(printf '%s\n' "$cli_json" | json_field phases.image.error.code)"
  if [ "$cli_code" -eq 0 ] && [ "$img_status" = "success" ] && [ "$img_err" != "language_unsupported_for_operation" ]; then
    pass "cli-image:$name ($lang)"
  else
    fail "cli-image:$name ($lang)" "exit=$cli_code image='$img_status' err='$img_err'"
  fi
done

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
