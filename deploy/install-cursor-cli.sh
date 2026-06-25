#!/usr/bin/env bash
# Cursor CLI — official install: https://cursor.com/docs/cli/installation
# ACP in Agent Canvas: command "agent", args "acp"
set -euo pipefail

AGENT_BIN=/usr/local/bin/agent
INSTALL_HOME="${CURSOR_CLI_HOME:-/root}"

if [ -x "$AGENT_BIN" ] && "$AGENT_BIN" --version >/dev/null 2>&1; then
  echo "[cursor-cli] already installed: $("$AGENT_BIN" --version)"
  exit 0
fi

export HOME="$INSTALL_HOME"
mkdir -p "$HOME/.local/bin"

echo "[cursor-cli] curl https://cursor.com/install -fsS | bash"
curl -4 -fsSL https://cursor.com/install | bash

if [ ! -x "$HOME/.local/bin/agent" ]; then
  echo "[cursor-cli] ERROR: $HOME/.local/bin/agent not found after install" >&2
  exit 1
fi

ln -sf "$HOME/.local/bin/agent" "$AGENT_BIN"
[ -e "$HOME/.local/bin/cursor-agent" ] && ln -sf "$HOME/.local/bin/cursor-agent" /usr/local/bin/cursor-agent

if ! "$AGENT_BIN" --version >/dev/null 2>&1; then
  echo "[cursor-cli] ERROR: agent --version failed" >&2
  "$AGENT_BIN" --version 2>&1 || true
  exit 1
fi

echo "[cursor-cli] installed: $("$AGENT_BIN" --version)"
echo "[cursor-cli] Canvas Manage Backends → command: agent  args: acp"
