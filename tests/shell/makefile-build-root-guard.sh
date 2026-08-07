#!/usr/bin/env bash
# Regression: project Makefile template must not use BUILD_ROOT ?= …
# Ambient BUILD_ROOT=project-cwd must not win over the dpk-build scripts root.
#
# Usage: bash tests/shell/makefile-build-root-guard.sh
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

TEMPLATE="$REPO_ROOT/templates/Makefile"
COMMON="$REPO_ROOT/Makefile.common"

if [ ! -f "$TEMPLATE" ]; then
  fail "template-exists" "missing $TEMPLATE"
else
  pass "template-exists"
  if grep -E '^BUILD_ROOT[[:space:]]*\?=' "$TEMPLATE" >/dev/null; then
    fail "template-no-question-assign" "templates/Makefile still uses BUILD_ROOT ?="
  else
    pass "template-no-question-assign"
  fi
  if grep -E '^BUILD_ROOT[[:space:]]*:=' "$TEMPLATE" >/dev/null; then
    pass "template-uses-immediate-assign"
  else
    fail "template-uses-immediate-assign" "expected BUILD_ROOT :="
  fi
  if grep -F 'abspath' "$TEMPLATE" >/dev/null; then
    pass "template-uses-abspath"
  else
    fail "template-uses-abspath" "expected abspath in BUILD_ROOT assignment"
  fi
fi

if [ ! -f "$COMMON" ]; then
  fail "common-exists" "missing $COMMON"
else
  pass "common-exists"
  if grep -F 'wildcard $(BUILD_ROOT)/bootstrap.sh' "$COMMON" >/dev/null \
    && grep -F 'is not a dpk-build tree' "$COMMON" >/dev/null; then
    pass "common-guards-bootstrap"
  else
    fail "common-guards-bootstrap" "Makefile.common should error when bootstrap.sh missing"
  fi
fi

# Smoke: forced BUILD_ROOT in a temp Makefile wins over ambient pollution
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/Makefile" <<EOF
BUILD_ROOT := ${REPO_ROOT}
include \$(BUILD_ROOT)/Makefile.common
EOF

if OUT="$(cd "$TMP" && BUILD_ROOT=/tmp/not-dpk-build make -n b 2>&1)"; then
  if printf '%s' "$OUT" | grep -F "$REPO_ROOT" >/dev/null; then
    pass "polluted-env-uses-forced-build-root"
  else
    fail "polluted-env-uses-forced-build-root" "expected forced BUILD_ROOT in make -n output"
  fi
else
  fail "polluted-env-make-n" "make -n b failed: $OUT"
fi

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
