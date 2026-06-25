#!/usr/bin/env bash
# Minimal Agent Canvas backend for sandbox runners (no ACP / Cursor on runner).
# Usage: install-agent-canvas-backend.sh [/path/to/env-file]
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

ENV_FILE="${1:-/etc/pmm-agentic-flow/runner.env}"
AGENT_USER="${AGENT_USER:-agentcanvas}"
AGENT_HOME="/home/${AGENT_USER}"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

if ! id "$AGENT_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$AGENT_USER"
fi

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh
fi
if [ ! -x "${AGENT_HOME}/.local/bin/uv" ]; then
  su - "$AGENT_USER" -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
fi

echo "[install-agent-canvas-backend] npm @openhands/agent-canvas@${AGENT_CANVAS_VERSION:-latest}"
npm install -g "@openhands/agent-canvas@${AGENT_CANVAS_VERSION:-latest}"

mkdir -p \
  "$AGENT_HOME/.openhands/storage" \
  "$AGENT_HOME/.openhands/workspaces" \
  "$AGENT_HOME/.openhands/automation" \
  "$AGENT_HOME/.openhands/agent-canvas" \
  /projects/pmm /projects/pmm-qa
chown -R "${AGENT_USER}:${AGENT_USER}" "$AGENT_HOME/.openhands" /projects

echo "[install-agent-canvas-backend] $(agent-canvas --version)"
