#!/usr/bin/env bash
# Cursor CLI — official install: https://cursor.com/docs/cli/installation
# ACP in Agent Canvas: command "agent", args "acp"
# Installed as agentcanvas user — Canvas runs ACP as that user, not root.
set -euo pipefail

AGENT_BIN=/usr/local/bin/agent
AGENT_USER="${AGENT_USER:-agentcanvas}"
AGENT_HOME="/home/${AGENT_USER}"

agent_works() {
  id "$AGENT_USER" >/dev/null 2>&1 \
    && su - "$AGENT_USER" -c 'agent --version' >/dev/null 2>&1
}

if agent_works; then
  echo "[cursor-cli] already installed: $(su - "$AGENT_USER" -c 'agent --version')"
  exit 0
fi

if ! id "$AGENT_USER" >/dev/null 2>&1; then
  echo "[cursor-cli] ERROR: user $AGENT_USER must exist (run install-agent-canvas.sh first)" >&2
  exit 1
fi

echo "[cursor-cli] curl https://cursor.com/install -fsS | bash (as $AGENT_USER)"
su - "$AGENT_USER" -c 'curl -4 -fsSL https://cursor.com/install | bash'

if [ ! -x "$AGENT_HOME/.local/bin/agent" ]; then
  echo "[cursor-cli] ERROR: $AGENT_HOME/.local/bin/agent not found after install" >&2
  exit 1
fi

ln -sf "$AGENT_HOME/.local/bin/agent" "$AGENT_BIN"
[ -e "$AGENT_HOME/.local/bin/cursor-agent" ] \
  && ln -sf "$AGENT_HOME/.local/bin/cursor-agent" /usr/local/bin/cursor-agent

if ! agent_works; then
  echo "[cursor-cli] ERROR: agent --version failed as $AGENT_USER" >&2
  su - "$AGENT_USER" -c 'agent --version' 2>&1 || true
  exit 1
fi

echo "[cursor-cli] installed: $(su - "$AGENT_USER" -c 'agent --version')"
echo "[cursor-cli] Canvas Manage Backends → command: agent  args: acp"
