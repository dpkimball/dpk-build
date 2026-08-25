#!/usr/bin/env bash
# Contract: cargo publish goes to Kellnr registry dpk, never crates.io.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$REPO_ROOT/rust/cargo-publish-registry.sh"

PASSED=0
FAILED=0
pass() { printf 'PASS %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; FAILED=$((FAILED + 1)); }

if [[ ! -x "$HELPER" ]]; then
  chmod +x "$HELPER"
fi

out="$(PUBLISH_CRATE=true "$HELPER" 2>/tmp/cpr.err || true)"
if [[ -s /tmp/cpr.err ]] && grep -q 'CARGO_REGISTRY' /tmp/cpr.err; then
  pass "missing-registry-refused"
else
  fail "missing-registry-refused" "expected error about CARGO_REGISTRY, got: $(cat /tmp/cpr.err) / $out"
fi

out="$(PUBLISH_CRATE=true CARGO_REGISTRY=crates-io "$HELPER" 2>/tmp/cpr.err || true)"
if grep -q 'crates.io' /tmp/cpr.err; then
  pass "crates-io-refused"
else
  fail "crates-io-refused" "expected crates.io refusal, got: $(cat /tmp/cpr.err) / $out"
fi

out="$(PUBLISH_CRATE=true CARGO_REGISTRY=crates.io "$HELPER" 2>/tmp/cpr.err || true)"
if grep -q 'crates.io' /tmp/cpr.err; then
  pass "crates.io-alias-refused"
else
  fail "crates.io-alias-refused" "expected crates.io refusal, got: $(cat /tmp/cpr.err)"
fi

out="$(PUBLISH_CRATE=true CARGO_REGISTRY=dpk "$HELPER" 2>/tmp/cpr.err)" || {
  fail "dpk-ok" "exit $? stderr=$(cat /tmp/cpr.err)"
  out=""
}
if [[ "$out" == $'--registry\ndpk\n--allow-dirty' ]]; then
  pass "dpk-flags"
else
  fail "dpk-flags" "got: $(printf '%q' "$out")"
fi

if grep -q 'Publishing to crates.io' "$REPO_ROOT/rust/build-crate.sh"; then
  fail "build-crate-no-crates-io-log" "build-crate.sh still mentions publishing to crates.io"
else
  pass "build-crate-no-crates-io-log"
fi

if grep -q 'cargo-publish-registry.sh' "$REPO_ROOT/rust/build-crate.sh"; then
  pass "build-crate-uses-helper"
else
  fail "build-crate-uses-helper" "build-crate.sh does not call cargo-publish-registry.sh"
fi

printf '%s passed, %s failed\n' "$PASSED" "$FAILED"
if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi
