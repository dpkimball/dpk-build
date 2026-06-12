#!/bin/bash
exec "$(dirname "${BASH_SOURCE[0]}")/rust/build-docker.sh" "$@"
