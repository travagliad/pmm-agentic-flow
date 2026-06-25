#!/usr/bin/env bash
# Host prerequisites: Node 22, uv, Docker (sandboxes only), agent-canvas user, Cursor CLI.
# OpenHands VM install: https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm
set -euo pipefail

AGENT_USER="${AGENT_USER:-agentcanvas}"
AGENT_HOME="/home/${AGENT_USER}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[install-host] Node.js 22 + git"
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi
apt-get install -y ca-certificates curl git jq

echo "[install-host] uv (agent server runtime)"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh
fi

echo "[install-host] user ${AGENT_USER}"
if ! id "$AGENT_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$AGENT_USER"
fi

echo "[install-host] Docker (per-chat sandboxes only)"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
mkdir -p /etc/docker
if ! grep -q '"ipv6"' /etc/docker/daemon.json 2>/dev/null; then
  printf '%s\n' '{ "ipv6": false }' > /etc/docker/daemon.json
  systemctl restart docker
  sleep 2
fi
systemctl enable docker
systemctl start docker
usermod -aG docker "$AGENT_USER"

echo "[install-host] Agent Canvas dirs"
mkdir -p \
  "$AGENT_HOME/.openhands/storage" \
  "$AGENT_HOME/.openhands/workspaces" \
  "$AGENT_HOME/.openhands/automation" \
  "$AGENT_HOME/.openhands/agent-canvas" \
  "$AGENT_HOME/.openhands/agent-canvas/conversations" \
  "$AGENT_HOME/.openhands/agent-canvas/bash_events" \
  /projects \
  /var/lib/pmm-agentic-flow/orchestrator
chown -R "${AGENT_USER}:${AGENT_USER}" "$AGENT_HOME/.openhands" /projects

echo "[install-host] @openhands/agent-canvas"
# shellcheck source=/dev/null
source /etc/pmm-agentic-flow/env 2>/dev/null || true
npm install -g "@openhands/agent-canvas@${AGENT_CANVAS_VERSION:-latest}"

echo "[install-host] Cursor CLI"
bash "$REPO_ROOT/deploy/install-cursor-cli.sh"

echo "[install-host] done - node $(node --version), agent-canvas $(agent-canvas --version 2>/dev/null || echo ok)"
