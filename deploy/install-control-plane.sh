#!/usr/bin/env bash
# Control plane: Node.js for orchestrator build only (no Agent Canvas, no Docker).
set -euo pipefail

echo "[install-control-plane] apt packages"
apt-get update
apt-get install -y ca-certificates curl gnupg git jq nginx

echo "[install-control-plane] Node.js 22.x"
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
  echo "[install-control-plane] ngrok"
  curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" > /etc/apt/sources.list.d/ngrok.list
  apt-get update
  apt-get install -y ngrok
  ngrok config add-authtoken "$NGROK_AUTHTOKEN"
fi

mkdir -p /var/lib/pmm-agentic-flow/orchestrator
echo "[install-control-plane] node $(node --version)"
