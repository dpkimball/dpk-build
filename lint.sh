#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"
source "$SCRIPT_DIR/common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

BUILD_LANG="${BUILD_LANG:-}"
if [ -z "$BUILD_LANG" ]; then
    if   [ -f "$PWD/Cargo.toml" ];   then BUILD_LANG="rust"
    elif [ -f "$PWD/pyproject.toml" ]; then BUILD_LANG="python"
    elif [ -f "$PWD/pom.xml" ] || [ -f "$PWD/build.gradle" ]; then BUILD_LANG="java"
    else
        log_error "Cannot detect project type. Set BUILD_LANG=python|rust|java in env.sh."
        exit 1
    fi
fi

log_step "Language: $BUILD_LANG"
exec "$SCRIPT_DIR/$BUILD_LANG/lint.sh" "$@"
