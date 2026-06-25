#!/usr/bin/env bash
# Control plane: Node.js, ngrok, Agent Canvas UI. Orchestrator built in bootstrap-host.sh.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_INSTALL=(apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

echo "[install-control-plane] apt packages"
apt-get update
"${APT_INSTALL[@]}" ca-certificates curl gnupg git jq nginx

echo "[install-control-plane] Node.js 22.x"
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  "${APT_INSTALL[@]}" nodejs
fi

if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
  echo "[install-control-plane] ngrok"
  curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" > /etc/apt/sources.list.d/ngrok.list
  apt-get update
  "${APT_INSTALL[@]}" ngrok
  mkdir -p /root/.config/ngrok
  HOME=/root ngrok config add-authtoken "$NGROK_AUTHTOKEN"
fi

mkdir -p /var/lib/pmm-agentic-flow/orchestrator
bash "$(dirname "$0")/install-agent-canvas.sh" /etc/pmm-agentic-flow/env
echo "[install-control-plane] node $(node --version)"
