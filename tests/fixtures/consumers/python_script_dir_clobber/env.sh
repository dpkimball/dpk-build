#!/bin/bash
# Simulates a consumer project that exports a generic SCRIPT_DIR, which used to
# steal dpk-build phase-script paths.
SCRIPT_DIR=/definitely/wrong/script-dir
export SCRIPT_DIR
export PROJECT_ROOT="$SCRIPT_DIR"
