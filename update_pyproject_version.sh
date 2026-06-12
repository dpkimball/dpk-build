#!/bin/bash
exec "$(dirname "${BASH_SOURCE[0]}")/python/update_pyproject_version.sh" "$@"
