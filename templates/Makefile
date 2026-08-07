# =============================================================================
# Project Makefile — copy this to your project root and customise two lines.
# =============================================================================

# Path to dpk-build (adjust ../ depth if the project is nested deeper).
# Use := (not ?=): ambient BUILD_ROOT is often the *project* cwd after
# deliver/agent shells, which would make include look for ./Makefile.common.
BUILD_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../dpk-build)

# Space-separated internal packages to auto-update before each build.
# Leave empty if this project has no internal dependencies.
# Examples: keepsake-services | keepsake-image-ai keepsake-services | dpk-client
INTERNAL_PKGS ?=

include $(BUILD_ROOT)/Makefile.common

# =============================================================================
# Project-specific targets only below this line.
# Standard targets (b, test, lint, clean, update-versions, help) come from
# Makefile.common — do NOT redefine them here.
# =============================================================================
