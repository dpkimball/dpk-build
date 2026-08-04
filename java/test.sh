#!/bin/bash
# Java test: Maven test suite.
set -euo pipefail
_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$_SCRIPTS_DIR/../env.sh"
# shellcheck source=/dev/null
source "$_SCRIPTS_DIR/../common.sh"
# shellcheck source=/dev/null
source "$_SCRIPTS_DIR/mvn-run.sh"

log_info "☕ Maven test ($(resolve_maven_pom))"
run_maven test
