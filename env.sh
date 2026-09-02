#!/bin/bash
# =============================================================================
# Shared environment for projects that include this build root (make b / deliver)
# =============================================================================
# Individual projects source this file and override project-specific variables.
#
# Usage in project env.sh:
#   source "$BUILD_ROOT/env.sh"
#   # Then override project-specific variables
# =============================================================================

# =============================================================================
# Global Project Paths (canonical: SSD — see paths.sh)
# =============================================================================
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=paths.sh
[ -f "$_SCRIPT_DIR/paths.sh" ] && source "$_SCRIPT_DIR/paths.sh"
# When this file is sourced, BUILD_ROOT is this directory.
export BUILD_ROOT="$_SCRIPT_DIR"
unset _SCRIPT_DIR

# =============================================================================
# Private registry ports (DEV environment)
# These match the NodePorts in the dev Kubernetes cluster.
# Projects that use different ports override these in their own env.sh.
# =============================================================================
export DPK_PYPI_PORT="${DPK_PYPI_PORT:-31126}"
export DPK_CARGO_PORT="${DPK_CARGO_PORT:-31127}"
export DOCKER_REGISTRY_PORT="${DOCKER_REGISTRY_PORT:-30500}"

# =============================================================================
# PyPI Configuration (shared across all projects)
# =============================================================================
export PYPI_HOST="${PYPI_HOST:-localhost}"
export PYPI_PORT="${DPK_PYPI_PORT}"
export PYPI_USERNAME="${PYPI_USERNAME:-admin}"
# No baked password — set PYPI_PASSWORD in the operator environment / project env.sh.
export PYPI_PASSWORD="${PYPI_PASSWORD:-}"
export PYPI_URL="http://${PYPI_HOST}:${PYPI_PORT}"

# =============================================================================
# Kellnr Cargo registry (shared). Same pattern as PyPI:
#   local make b → localhost + DPK_CARGO_PORT (DEV NodePort)
#   CI → secrets.PRIVATE_CARGO_URL (analog of PRIVATE_PYPI_URL)
# Never set Cargo [registry] default. Never put host:port in workflow YAML.
# =============================================================================
export CARGO_HOST="${CARGO_HOST:-localhost}"
export CARGO_PORT="${DPK_CARGO_PORT}"
export CARGO_REGISTRIES_DPK_INDEX="${CARGO_REGISTRIES_DPK_INDEX:-sparse+http://${CARGO_HOST}:${CARGO_PORT}/api/v1/crates/}"
# Token: CARGO_REGISTRIES_DPK_TOKEN or ~/.cargo/credentials.toml — never commit it.
if [ -z "${CI:-}" ]; then
  export PUBLISH_CRATE="${PUBLISH_CRATE:-true}"
  export CARGO_REGISTRY="${CARGO_REGISTRY:-dpk}"
fi

# =============================================================================
# UV Index URLs (shared across all projects)
# =============================================================================
# UV index URLs: separate for tests (host) and Docker builds (container)
export UV_INDEX_URL_TEST="http://${PYPI_USERNAME}:${PYPI_PASSWORD}@${PYPI_HOST}:${DPK_PYPI_PORT}/simple"
export UV_INDEX_URL_BUILD="http://${PYPI_USERNAME}:${PYPI_PASSWORD}@host.docker.internal:${DPK_PYPI_PORT}/simple"
export UV_EXTRA_INDEX_URL="${UV_EXTRA_INDEX_URL:-https://pypi.org/simple}"

# Host commands (lint, test, uv sync) always use localhost PyPI — never a stale shell UV_INDEX_URL.
export UV_INDEX_URL="$UV_INDEX_URL_TEST"

# =============================================================================
# Docker registry
# =============================================================================
export DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL:-localhost:${DOCKER_REGISTRY_PORT}}"
export DOCKER_REGISTRY_CLUSTER_URL="${DOCKER_REGISTRY_CLUSTER_URL:-docker-registry-service.dev.svc.cluster.local:5000}"

# =============================================================================
# Build & Test Flags
# =============================================================================
# Note: SKIP_* flags are project-specific and should be set in each project's env.sh.
# They are NOT set here to allow each project to define its own defaults.

# =============================================================================
# Kubernetes/Helm Configuration (defaults - can be overridden by projects)
# =============================================================================
export K8S_DEPLOY="${K8S_DEPLOY:-true}"
export K8S_NAMESPACE="${K8S_NAMESPACE:-dev}"
# Optional operator QA host — never bake a LAN IP default (OSS / portable consumers).
export QA_BOX_IP="${QA_BOX_IP:-}"

# =============================================================================
# Common Build Variables (defaults - can be overridden by projects)
# =============================================================================
export CLEAN="${CLEAN:-false}"
export DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
export ENV_STORE="${ENV_STORE:-$BUILD_ROOT/.env.versions}"
export TAG="${TAG:-$(date +"%Y%m%d-%H%M")}"
export DEFAULT_IMAGE_TAG="${DEFAULT_IMAGE_TAG:-latest}"
export COLOR_GREEN="${COLOR_GREEN:-\033[0;32m}"
export TEST_DIRECTORY="${TEST_DIRECTORY:-tests}"
export PYTHON_VERSION="${PYTHON_VERSION:-python3.10}"
export PROJECT_VENV_DIR="${PROJECT_VENV_DIR:-.venv}"
export PROJECT_JUPYTER_VENV_DIR="${PROJECT_JUPYTER_VENV_DIR:-.jupyter_venv}"
