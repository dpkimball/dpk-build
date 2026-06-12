#!/bin/bash
exec "$(dirname "${BASH_SOURCE[0]}")/python/deploy-k8s.sh" "$@"
