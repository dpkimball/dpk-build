#!/bin/bash
# =============================================================================
# Canonical Keepsake paths (external SSD)
# =============================================================================
# Source from ~/.keepsake-storage.env, dpk-build/env.sh, or project env.sh.
# Override KEEPSAKE_SSD before sourcing if the volume name differs.
# =============================================================================

export KEEPSAKE_SSD="${KEEPSAKE_SSD:-/Volumes/KeepsakeSSD}"
export KEEPSAKE_PROJECT_ROOT="${KEEPSAKE_PROJECT_ROOT:-$KEEPSAKE_SSD/keepsake-workspace}"
export KEEPSAKE_SCRIPTS_ROOT="${KEEPSAKE_SCRIPTS_ROOT:-$KEEPSAKE_PROJECT_ROOT/dpk-build}"
export KEEPSAKE_COMPOSE_PROJECT_ROOT="${KEEPSAKE_COMPOSE_PROJECT_ROOT:-$KEEPSAKE_PROJECT_ROOT/keepsake}"
export PYPI_PACKAGE_DIR="${PYPI_PACKAGE_DIR:-$KEEPSAKE_PROJECT_ROOT/keepsake-pypi/keepsake-pypi/packages}"
