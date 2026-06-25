#!/usr/bin/env bash
# Sandbox runner: PMM workspace + QA tools (no Agent Canvas, no ACP).
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_INSTALL=(apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

apt-get update
"${APT_INSTALL[@]}" ca-certificates curl git jq python3 python3-pip docker.io

systemctl enable --now docker 2>/dev/null || true

mkdir -p /projects/pmm /projects/pmm-qa /var/lib/pmm-agentic-flow

echo "[install-runner] Node.js 22.x from NodeSource"
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  "${APT_INSTALL[@]}" nodejs
fi

node --version
python3 --version
echo "[install-runner] QA runner tools ready (no agent-canvas)"
