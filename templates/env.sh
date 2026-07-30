#!/bin/bash
# =============================================================================
# Project env.sh — copy this to your project root and fill in the blanks.
# Delete the block (service OR library) that doesn't apply.
# =============================================================================

# Bootstrap BUILD_ROOT without hardcoding the umbrella folder name.
# Prefer sibling ../dpk-build (works under any workspace directory name).
if [ -z "${BUILD_ROOT:-}" ]; then
  if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  else
    _ENV_DIR="$(cd "$(dirname "$0")" && pwd)"
  fi
  if [ -f "${_ENV_DIR}/../dpk-build/env.sh" ]; then
    export BUILD_ROOT="$(cd "${_ENV_DIR}/../dpk-build" && pwd)"
  fi
  unset _ENV_DIR
fi
# shellcheck source=/dev/null
source "${BUILD_ROOT}/env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Required for every project ────────────────────────────────────────────────
export PROJECT_ROOT="$SCRIPT_DIR"
export PYPROJECT="$PROJECT_ROOT/pyproject.toml"
export PROJECT_VENV_DIR="$PROJECT_ROOT/.venv"
export DIST_DIR="$PROJECT_ROOT/dist"
export TEST_DIRECTORY="$PROJECT_ROOT/tests"

# =============================================================================
# SERVICE (deploys a Docker image to Kubernetes) — delete if library
# =============================================================================
export IMAGE_NAME="my-service"             # Docker image name

export SKIP_LINT="false"
export SKIP_TESTS="false"
export SKIP_WHEEL="true"                   # services don't publish wheels
export SKIP_DOCKER_IMAGE="false"
export SKIP_K8S_DEPLOY="false"

export K8S_DEPLOY="true"
export K8S_NAMESPACE="dev"                 # or "dagster" for Dagster services
export HELM_RELEASE="my-service"
export HELM_CHART_PATH="${HELM_CHART_PATH:-${WORKSPACE_ROOT}/dpk-infra/charts/my-service}"

# =============================================================================
# LIBRARY (publishes a wheel to local PyPI) — delete if service
# =============================================================================
export IMAGE_NAME=""                       # libraries have no Docker image

export SKIP_LINT="false"
export SKIP_TESTS="false"
export SKIP_WHEEL="false"                  # libraries publish wheels
export SKIP_DOCKER_IMAGE="true"
export SKIP_K8S_DEPLOY="true"
