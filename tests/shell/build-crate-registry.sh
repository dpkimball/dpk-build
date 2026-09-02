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

out="$(env -u CARGO_REGISTRY PUBLISH_CRATE=true "$HELPER" 2>/tmp/cpr.err || true)"
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

# Local make b (CI unset) must default to Kellnr, like Python → pypiserver.
got="$(env -u PUBLISH_CRATE -u CARGO_REGISTRY -u CI bash -c "set -a; source '$REPO_ROOT/env.sh'; set +a; printf '%s %s' \"\$PUBLISH_CRATE\" \"\$CARGO_REGISTRY\"")"
if [[ "$got" == "true dpk" ]]; then
  pass "env-sh-local-defaults-dpk"
else
  fail "env-sh-local-defaults-dpk" "got: $got"
fi
got_ci="$(env -u PUBLISH_CRATE CI=true bash -c "set -a; source '$REPO_ROOT/env.sh'; set +a; printf '%s' \"\${PUBLISH_CRATE-}\"")"
if [[ -z "$got_ci" ]]; then
  pass "env-sh-ci-does-not-default-publish"
else
  fail "env-sh-ci-does-not-default-publish" "CI=true still set PUBLISH_CRATE=$got_ci"
fi

idx="$(env -u CARGO_REGISTRIES_DPK_INDEX -u CARGO_HOST bash -c "set -a; source '$REPO_ROOT/env.sh'; set +a; printf '%s' \"\$CARGO_REGISTRIES_DPK_INDEX\"")"
if [[ "$idx" == sparse+http://localhost:*/api/v1/crates/ ]] && [[ "$idx" != *192.168* ]]; then
  pass "env-sh-index-localhost-not-lan-ip"
else
  fail "env-sh-index-localhost-not-lan-ip" "got: $idx"
fi

printf '%s passed, %s failed\n' "$PASSED" "$FAILED"
if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi
