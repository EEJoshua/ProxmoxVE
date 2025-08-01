#!/usr/bin/env bash
# Executed automatically INSIDE the new LXC by build.func
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[INFO] Preparing Debian for Swizzin..."
apt-get update -qq
apt-get install -y curl wget gnupg lsb-release

echo "[INFO] Launching upstream Swizzin installer..."
bash <(curl -sL git.io/swizzin)

echo "[OK] Swizzin base installation complete.  Re‑login and run 'box' to add apps."
