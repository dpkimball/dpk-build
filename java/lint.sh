#!/bin/bash
# Java lint: Maven validate + compile (no tests).
set -euo pipefail
_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$_SCRIPTS_DIR/../env.sh"
# shellcheck source=/dev/null
source "$_SCRIPTS_DIR/../common.sh"
# shellcheck source=/dev/null
source "$_SCRIPTS_DIR/mvn-run.sh"

log_info "☕ Maven lint: validate + compile ($(resolve_maven_pom))"
run_maven -DskipTests validate compile
