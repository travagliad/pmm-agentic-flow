#!/usr/bin/env bash
# Install GitHub Copilot CLI for ACP to /usr/local/bin/copilot.
set -euo pipefail

COPILOT_BIN=/usr/local/bin/copilot

if [ -x "$COPILOT_BIN" ]; then
  echo "[copilot-cli] already installed: $COPILOT_BIN"
  exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "[copilot-cli] ERROR: npm not found — install Node.js first" >&2
  exit 1
fi

echo "[copilot-cli] installing @github/copilot to /usr/local"
npm_config_ignore_scripts=false npm install -g @github/copilot --prefix /usr/local

if [ ! -x "$COPILOT_BIN" ]; then
  echo "[copilot-cli] ERROR: $COPILOT_BIN not found after npm install" >&2
  exit 1
fi

echo "[copilot-cli] installed: $($COPILOT_BIN --version 2>/dev/null || echo @github/copilot)"
