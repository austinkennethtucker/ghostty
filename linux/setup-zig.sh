#!/usr/bin/env bash
set -euo pipefail

# Install Zig 0.15.2 on Linux (x86_64 or aarch64).
#
# Usage:
#   sudo ./linux/setup-zig.sh

ZIG_VERSION="0.15.2"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)  ZIG_ARCH="x86_64" ;;
    aarch64) ZIG_ARCH="aarch64" ;;
    *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

TARBALL="zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz"
URL="https://ziglang.org/download/${ZIG_VERSION}/${TARBALL}"
INSTALL_DIR="/opt/zig-linux-${ZIG_ARCH}-${ZIG_VERSION}"

if [ -x "$INSTALL_DIR/zig" ]; then
    echo "Zig ${ZIG_VERSION} already installed at ${INSTALL_DIR}"
    "$INSTALL_DIR/zig" version
    exit 0
fi

echo "==> Downloading Zig ${ZIG_VERSION} for ${ZIG_ARCH}..."
cd /tmp
wget -q --show-progress "$URL"

echo "==> Installing to ${INSTALL_DIR}..."
tar xf "$TARBALL" -C /opt/
ln -sf "$INSTALL_DIR/zig" /usr/local/bin/zig
rm -f "$TARBALL"

echo "==> Installed: zig $(/usr/local/bin/zig version)"

# Add to PATH for the invoking user (not root)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo "~${REAL_USER}")"
PROFILE="${REAL_HOME}/.bashrc"
[ -f "${REAL_HOME}/.zshrc" ] && PROFILE="${REAL_HOME}/.zshrc"
if ! grep -q "/usr/local/bin" "$PROFILE" 2>/dev/null; then
    echo 'export PATH="/usr/local/bin:$PATH"' >> "$PROFILE"
    echo "==> Added /usr/local/bin to PATH in ${PROFILE}"
    echo "    Run: source ${PROFILE}"
fi
