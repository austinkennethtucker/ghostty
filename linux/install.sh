#!/usr/bin/env bash
set -euo pipefail

# Build and install Trident to a prefix directory.
#
# Usage:
#   sudo ./linux/install.sh                  # Install to /usr/local (default)
#   sudo ./linux/install.sh /usr             # Install to /usr
#   OPTIMIZE=Debug ./linux/install.sh ~/.local  # Debug build, no sudo needed

PREFIX="${1:-/usr/local}"
OPTIMIZE="${OPTIMIZE:-ReleaseFast}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

echo "==> Building Trident (optimize=${OPTIMIZE}, prefix=${PREFIX})"
zig build \
    "-Doptimize=${OPTIMIZE}" \
    -Dcpu=baseline \
    -Dpie=true \
    --prefix "${PREFIX}"

echo "==> Installed to ${PREFIX}"
echo "    Binary:       ${PREFIX}/bin/ghostty"
echo "    Desktop file: ${PREFIX}/share/applications/"
echo "    Icons:        ${PREFIX}/share/icons/hicolor/"
echo "    Man pages:    ${PREFIX}/share/man/"
echo "    Completions:  ${PREFIX}/share/bash-completion/ ${PREFIX}/share/zsh/ ${PREFIX}/share/fish/"
