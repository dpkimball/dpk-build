#!/bin/bash
exec "$(dirname "${BASH_SOURCE[0]}")/rust/load-k8s.sh" "$@"
