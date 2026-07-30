#!/bin/bash
# =============================================================================
# Canonical workspace paths (external SSD)
# =============================================================================
# Sourced from dpk-build/env.sh (and optionally from ~/.profile).
# Override SSD / WORKSPACE_ROOT / BUILD_ROOT before sourcing if needed.
#
# Naming: no KEEPSAKE_ prefix. Folder rename lives ONLY here.
# Consumers should bootstrap via sibling ../dpk-build — never hardcode the
# umbrella directory name.
#
# WORKSPACE_ROOT = umbrella checkout (dpk-workspace).
# PROJECT_ROOT   = set by each project's env.sh to that repo (not set here).
# BUILD_ROOT     = this dpk-build tree.
# =============================================================================

# Accept legacy KEEPSAKE_* only as input fallbacks during cutover.
export SSD="${SSD:-${KEEPSAKE_SSD:-/Volumes/KeepsakeSSD}}"

if [ -z "${WORKSPACE_ROOT:-}" ] && [ -z "${KEEPSAKE_PROJECT_ROOT:-}" ]; then
  if [ -d "${SSD}/dpk-workspace" ]; then
    export WORKSPACE_ROOT="${SSD}/dpk-workspace"
  elif [ -d "${SSD}/keepsake-workspace" ]; then
    # Legacy symlink / old folder name — remove once nothing mounts it.
    export WORKSPACE_ROOT="${SSD}/keepsake-workspace"
  else
    export WORKSPACE_ROOT="${SSD}/dpk-workspace"
  fi
else
  export WORKSPACE_ROOT="${WORKSPACE_ROOT:-$KEEPSAKE_PROJECT_ROOT}"
fi

export BUILD_ROOT="${BUILD_ROOT:-${KEEPSAKE_SCRIPTS_ROOT:-$WORKSPACE_ROOT/dpk-build}}"
