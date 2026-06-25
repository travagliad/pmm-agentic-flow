#!/usr/bin/env bash
# Build tools for PMM dev on control plane / runners.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
APT_INSTALL=(apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

apt-get update
"${APT_INSTALL[@]}" make build-essential

# UI builds need tsc (typescript) — global via npm if node present
if command -v npm >/dev/null 2>&1; then
  npm install -g typescript 2>/dev/null || true
fi

echo "[install-build-tools] make $(make --version | head -1)"
