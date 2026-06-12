#!/bin/bash
print_status()  { echo -e "\033[1;32m✔ $*\033[0m"; }
print_warning() { echo -e "\033[1;33m⚠ $*\033[0m"; }
print_error()   { echo -e "\033[1;31m✘ $*\033[0m"; }
require_tool()  { command -v "$1" >/dev/null || { print_error "$1 is required"; exit 1; }; }

# Canonical log_* function set
log_info()    { echo -e "\033[0;34mℹ $*\033[0m"; }
log_success() { echo -e "\033[0;32m✔ $*\033[0m"; }
log_error()   { echo -e "\033[0;31m✘ $*\033[0m"; }
log_warning() { echo -e "\033[0;33m⚠ $*\033[0m"; }
log_step()    { echo -e "\033[0;36m→ $*\033[0m"; }

# print_status is an alias for log_info (backward compat)
# shellcheck disable=SC2120
print_status() { log_info "$@"; }
