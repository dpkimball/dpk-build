#!/bin/bash
print_status()  { echo -e "\033[1;32m✔ $*\033[0m"; }
print_warning() { echo -e "\033[1;33m⚠ $*\033[0m"; }
print_error()   { echo -e "\033[1;31m✘ $*\033[0m"; }
require_tool()  { command -v "$1" >/dev/null || { print_error "$1 is required"; exit 1; }; }
