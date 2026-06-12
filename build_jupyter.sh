#!/bin/bash
exec "$(dirname "${BASH_SOURCE[0]}")/python/build-jupyter.sh" "$@"
