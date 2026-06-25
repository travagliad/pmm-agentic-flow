#!/usr/bin/env bash
# Sandbox runner: backend-only Agent Canvas + PMM workspace (no UI, no ACP).
# https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_INSTALL=(apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

apt-get update
"${APT_INSTALL[@]}" ca-certificates curl gnupg git jq

echo "[install-runner] Node.js 22.x from NodeSource"
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  "${APT_INSTALL[@]}" nodejs
fi

bash "$(dirname "$0")/install-agent-canvas-backend.sh" /etc/pmm-agentic-flow/runner.env

node --version
uv --version
agent-canvas --version
