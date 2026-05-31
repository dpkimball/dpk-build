#!/bin/bash
print_status()  { echo -e "\033[1;32m✔ $*\033[0m"; }
print_warning() { echo -e "\033[1;33m⚠ $*\033[0m"; }
print_error()   { echo -e "\033[1;31m✘ $*\033[0m"; }
require_tool()  { command -v "$1" >/dev/null || { print_error "$1 is required"; exit 1; }; }

# log_* aliases — previously in utils.sh; consolidated here
log_info()    { echo -e "\033[1;34mℹ️ $1\033[0m"; }
log_success() { echo -e "\033[1;32m✅ $1\033[0m"; }
log_error()   { echo -e "\033[1;31m❌ $1\033[0m"; }
log_warning() { echo -e "\033[1;33m⚠️ $1\033[0m"; }
