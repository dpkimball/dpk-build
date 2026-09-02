#!/bin/bash
# Mirrors binder-cloud/frontend: do not use SCRIPT_DIR.
_FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$_FRONTEND_DIR"
export IMAGE_NAME="${IMAGE_NAME:-contract-node}"
export VITE_API_URL=""
