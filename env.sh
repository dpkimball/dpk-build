#!/bin/bash
# =============================================================================
# Keepsake Shared Environment Configuration
# =============================================================================
# This file contains shared environment variables used across all Keepsake projects.
# Individual projects can source this file and override project-specific variables.
#
# Usage in project env.sh:
#   source "$KEEPSAKE_SCRIPTS_ROOT/env.sh"
#   # Then override project-specific variables
# =============================================================================

# =============================================================================
# Global Project Paths
# =============================================================================
export KEEPSAKE_PROJECT_ROOT="${KEEPSAKE_PROJECT_ROOT:-$HOME/PycharmProjects}"
export KEEPSAKE_SCRIPTS_ROOT="${KEEPSAKE_SCRIPTS_ROOT:-$KEEPSAKE_PROJECT_ROOT/keepsake-scripts}"
export PYPI_PACKAGE_DIR="${PYPI_PACKAGE_DIR:-$KEEPSAKE_PROJECT_ROOT/keepsake-pypi/keepsake-pypi/packages}"

# =============================================================================
# Service Ports (DEV environment - shared across all projects)
# =============================================================================
# These match the NodePorts in keepsake-dev Kubernetes cluster
# Backend uses 31325 to match QA for consistency
export KEEPSAKE_BACKEND_PORT="${KEEPSAKE_BACKEND_PORT:-31325}"
export KEEPSAKE_FRONTEND_PORT="${KEEPSAKE_FRONTEND_PORT:-30004}"
export KEEPSAKE_DAGSTER_PORT="${KEEPSAKE_DAGSTER_PORT:-30005}"
export KEEPSAKE_PYPI_PORT="${KEEPSAKE_PYPI_PORT:-31126}"
export DPK_PORT="${DPK_PORT:-31605}"
export KEEPSAKE_MONGO_PORT="${KEEPSAKE_MONGO_PORT:-32643}"
export KEEPSAKE_LANGGRAPH_PORT="${KEEPSAKE_LANGGRAPH_PORT:-30080}"
export DPK_DASHBOARD_PORT="${DPK_DASHBOARD_PORT:-30002}"
export CLICKHOUSE_HTTP_PORT="${CLICKHOUSE_HTTP_PORT:-31234}"
export CLICKHOUSE_TCP_PORT="${CLICKHOUSE_TCP_PORT:-31235}"

# =============================================================================
# Service URLs (local development - shared across all projects)
# =============================================================================
export KEEPSAKE_BACKEND_URL="http://localhost:${KEEPSAKE_BACKEND_PORT}"
export KEEPSAKE_FRONTEND_URL="http://localhost:${KEEPSAKE_FRONTEND_PORT}"
export KEEPSAKE_DAGSTER_URL="http://localhost:${KEEPSAKE_DAGSTER_PORT}"
export KEEPSAKE_PYPI_URL="http://localhost:${KEEPSAKE_PYPI_PORT}"
export KEEPSAKE_API_URL="${KEEPSAKE_BACKEND_URL}/api"
export KEEPSAKE_API_V1_URL="${KEEPSAKE_BACKEND_URL}/api/v1"
export LANGGRAPH_URL="http://localhost:${KEEPSAKE_LANGGRAPH_PORT}"
export MEMORY_GRAPH_URL="http://localhost:${DPK_PORT}"
export DPK_DASHBOARD_URL="http://localhost:${DPK_DASHBOARD_PORT}"
export KEEPSAKE_MONGO_URI="${KEEPSAKE_MONGO_URI:-mongodb://keepsake_user:keepsake_pass@localhost:${KEEPSAKE_MONGO_PORT}/keepsake?authSource=keepsake}"
export CLICKHOUSE_HTTP_URL="http://localhost:${CLICKHOUSE_HTTP_PORT}"

# =============================================================================
# API Endpoints (derived from service URLs)
# =============================================================================
export BRAIN_API_URL="${LANGGRAPH_URL}/api/v1"

export MONGO_URI="${MONGO_URI:-${KEEPSAKE_MONGO_URI}}"

# =============================================================================
# PyPI Configuration (shared across all projects)
# =============================================================================
export PYPI_HOST="${PYPI_HOST:-localhost}"
export PYPI_PORT="${PYPI_PORT:-${KEEPSAKE_PYPI_PORT}}"
export PYPI_USERNAME="${PYPI_USERNAME:-admin}"
export PYPI_PASSWORD="${PYPI_PASSWORD:-your-secret-password}"
export PYPI_URL="http://${PYPI_HOST}:${PYPI_PORT}"

# =============================================================================
# UV Index URLs (shared across all projects)
# =============================================================================
# UV index URLs: separate for tests (host) and Docker builds (container)
export UV_INDEX_URL_TEST="http://${PYPI_USERNAME}:${PYPI_PASSWORD}@${PYPI_HOST}:${KEEPSAKE_PYPI_PORT}/simple"
export UV_INDEX_URL_BUILD="http://${PYPI_USERNAME}:${PYPI_PASSWORD}@host.docker.internal:${KEEPSAKE_PYPI_PORT}/simple"
export UV_EXTRA_INDEX_URL="${UV_EXTRA_INDEX_URL:-https://pypi.org/simple}"

# Default UV_INDEX_URL to the test variant for local commands
export UV_INDEX_URL="${UV_INDEX_URL:-$UV_INDEX_URL_TEST}"

# =============================================================================
# Build & Test Flags
# =============================================================================
# Note: SKIP_* flags are project-specific and should be set in each project's env.sh
# They are NOT set here to allow each project to define its own defaults

# =============================================================================
# Kubernetes/Helm Configuration (defaults - can be overridden by projects)
# =============================================================================
export K8S_DEPLOY="${K8S_DEPLOY:-true}"
export K8S_NAMESPACE="${K8S_NAMESPACE:-dev}"
export QA_BOX_IP="${QA_BOX_IP:-192.168.86.47}"

# =============================================================================
# Compatibility Aliases (for code that uses different variable names)
# =============================================================================
export BASE_URL="${BASE_URL:-${KEEPSAKE_API_URL}}"
export LANGGRAPH_BASE_URL="${LANGGRAPH_BASE_URL:-${LANGGRAPH_URL}}"
export FRONTEND_URL="${FRONTEND_URL:-${KEEPSAKE_FRONTEND_URL}}"

# =============================================================================
# Common Build Variables (defaults - can be overridden by projects)
# =============================================================================
export CLEAN="${CLEAN:-false}"
export DOCKERFILE_DIR="${DOCKERFILE_DIR:-.}"
export ENV_STORE="${ENV_STORE:-$KEEPSAKE_SCRIPTS_ROOT/.env.versions}"
export TAG="${TAG:-$(date +"%Y%m%d-%H%M")}"
export DEFAULT_IMAGE_TAG="${DEFAULT_IMAGE_TAG:-latest}"
export COLOR_GREEN="${COLOR_GREEN:-\033[0;32m}"
export TEST_DIRECTORY="${TEST_DIRECTORY:-tests}"
export PYTHON_VERSION="${PYTHON_VERSION:-python3.10}"
export PROJECT_VENV_DIR="${PROJECT_VENV_DIR:-.venv}"
export PROJECT_JUPYTER_VENV_DIR="${PROJECT_JUPYTER_VENV_DIR:-.jupyter_venv}"
