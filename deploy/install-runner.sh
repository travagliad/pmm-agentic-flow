#!/usr/bin/env bash
# Chat runner: one Linode VM = one chat. Agent Canvas on host (process sandbox), no Docker.
# https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm
set -euo pipefail

AGENT_USER="${AGENT_USER:-agentcanvas}"
AGENT_HOME="/home/${AGENT_USER}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

apt-get update
apt-get install -y ca-certificates curl gnupg git jq

echo "[install-runner] Node.js 22.x from NodeSource"
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

if ! id "$AGENT_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$AGENT_USER"
fi

echo "[install-runner] uv"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh
fi
if [ ! -x "${AGENT_HOME}/.local/bin/uv" ]; then
  su - "$AGENT_USER" -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
fi

# shellcheck source=/dev/null
source /etc/pmm-agentic-flow/runner.env 2>/dev/null || true
npm install -g "@openhands/agent-canvas@${AGENT_CANVAS_VERSION:-latest}"

bash "$REPO_ROOT/deploy/install-cursor-cli.sh" || true

mkdir -p \
  "$AGENT_HOME/.openhands/storage" \
  "$AGENT_HOME/.openhands/workspaces" \
  "$AGENT_HOME/.openhands/automation" \
  "$AGENT_HOME/.openhands/agent-canvas" \
  /projects/pmm /projects/pmm-qa
chown -R "${AGENT_USER}:${AGENT_USER}" "$AGENT_HOME/.openhands" /projects

node --version
uv --version
agent-canvas --version
