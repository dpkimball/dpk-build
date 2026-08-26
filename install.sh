#!/usr/bin/env bash
# install.sh — install dpk-build binary from GitHub Releases
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/dpkimball/dpk-build/master/install.sh | bash
#   curl -fsSL ... | DPKBUILD_VERSION=v0.1.0 bash
#   INSTALL_DIR=/usr/local/bin bash install.sh
#
# Environment:
#   DPKBUILD_VERSION  — tag to install (default: latest)
#   INSTALL_DIR       — destination directory (default: ~/.local/bin)
#   GITHUB_TOKEN      — optional, avoids rate limits on the releases API

set -euo pipefail

REPO="dpkimball/dpk-build"
BINARY="dpk-build"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
DPKBUILD_VERSION="${DPKBUILD_VERSION:-}"

# ── Platform detection ────────────────────────────────────────────────────────

OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}-${ARCH}" in
  Linux-x86_64)   PLATFORM="linux-x86_64"  ;;
  Linux-aarch64)  PLATFORM="linux-aarch64" ;;
  Darwin-arm64)   PLATFORM="macos-aarch64" ;;
  Darwin-x86_64)  PLATFORM="macos-x86_64"  ;;
  *)
    echo "error: unsupported platform ${OS}-${ARCH}" >&2
    exit 1
    ;;
esac

# ── Resolve version ───────────────────────────────────────────────────────────

if [[ -z "$DPKBUILD_VERSION" ]]; then
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
  AUTH_HEADER=""
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    AUTH_HEADER="Authorization: Bearer ${GITHUB_TOKEN}"
  fi
  if [[ -n "$AUTH_HEADER" ]]; then
    DPKBUILD_VERSION="$(curl -fsSL -H "$AUTH_HEADER" "$API_URL" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"
  else
    DPKBUILD_VERSION="$(curl -fsSL "$API_URL" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"
  fi
fi

if [[ -z "$DPKBUILD_VERSION" ]]; then
  echo "error: could not determine version to install" >&2
  exit 1
fi

# ── Skip if already installed at the right version ───────────────────────────

if command -v "$BINARY" >/dev/null 2>&1; then
  CURRENT="$("$BINARY" version 2>/dev/null || true)"
  if echo "$CURRENT" | grep -qF "${DPKBUILD_VERSION#v}"; then
    echo "dpk-build ${DPKBUILD_VERSION} already installed at $(command -v "$BINARY")"
    exit 0
  fi
fi

# ── Download and install ──────────────────────────────────────────────────────

ARCHIVE="dpk-build-${DPKBUILD_VERSION}-${PLATFORM}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${DPKBUILD_VERSION}/${ARCHIVE}"

echo "installing dpk-build ${DPKBUILD_VERSION} for ${PLATFORM} …"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$URL" -o "$TMP/$ARCHIVE"
tar -xzf "$TMP/$ARCHIVE" -C "$TMP"

mkdir -p "$INSTALL_DIR"
install -m 755 "$TMP/$BINARY" "$INSTALL_DIR/$BINARY"

echo "installed: $INSTALL_DIR/$BINARY"

# Remind the user to add INSTALL_DIR to PATH if it's not already there.
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    echo ""
    echo "note: add ${INSTALL_DIR} to your PATH:"
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
    ;;
esac
