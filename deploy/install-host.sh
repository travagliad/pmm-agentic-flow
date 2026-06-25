#!/usr/bin/env bash
# Matches OpenHands VM install steps:
# https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm
set -euo pipefail

AGENT_USER="${AGENT_USER:-agentcanvas}"
AGENT_HOME="/home/${AGENT_USER}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[install-host] apt packages (ca-certificates curl gnupg git)"
apt-get update
apt-get install -y ca-certificates curl gnupg git jq nginx

echo "[install-host] Node.js 22.x from NodeSource"
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

echo "[install-host] user ${AGENT_USER}"
if ! id "$AGENT_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$AGENT_USER"
fi

echo "[install-host] uv for agent server runtime (agentcanvas + system PATH)"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh
fi
if [ ! -f "${AGENT_HOME}/.local/bin/uv" ]; then
  su - "$AGENT_USER" -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
fi

echo "[install-host] @openhands/agent-canvas (global npm)"
# shellcheck source=/dev/null
source /etc/pmm-agentic-flow/env 2>/dev/null || true
npm install -g "@openhands/agent-canvas@${AGENT_CANVAS_VERSION:-latest}"

echo "[install-host] Docker Engine (Agent Canvas per-chat sandboxes only)"
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

if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
  echo "[install-host] ngrok"
  curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" > /etc/apt/sources.list.d/ngrok.list
  apt-get update
  apt-get install -y ngrok
  ngrok config add-authtoken "$NGROK_AUTHTOKEN"
fi

echo "[install-host] Cursor CLI (ACP backend, optional)"
bash "$REPO_ROOT/deploy/install-cursor-cli.sh" || echo "[install-host] Cursor CLI skipped"

echo "[install-host] versions:"
node --version
uv --version
agent-canvas --version
