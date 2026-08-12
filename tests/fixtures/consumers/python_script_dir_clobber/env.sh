#!/bin/bash
# Mirrors keepsake-media / resume-pipeline: a generic SCRIPT_DIR that used to
# steal dpk-build phase-script paths.
SCRIPT_DIR=/definitely/wrong/script-dir
export SCRIPT_DIR
export PROJECT_ROOT="$SCRIPT_DIR"
