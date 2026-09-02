#!/bin/bash
# =============================================================================
# Canonical workspace paths (external SSD)
# =============================================================================
# Sourced from dpk-build/env.sh (and optionally from ~/.profile).
# Override SSD / WORKSPACE_ROOT / BUILD_ROOT before sourcing if needed.
#
# WORKSPACE_ROOT = umbrella checkout (dpk-workspace).
# PROJECT_ROOT   = set by each project's env.sh to that repo (not set here).
# BUILD_ROOT     = this dpk-build tree.
# =============================================================================

export SSD="${SSD:-/Volumes/SSD}"

if [ -z "${WORKSPACE_ROOT:-}" ]; then
  export WORKSPACE_ROOT="${SSD}/dpk-workspace"
fi

export BUILD_ROOT="${BUILD_ROOT:-$WORKSPACE_ROOT/dpk-build}"
