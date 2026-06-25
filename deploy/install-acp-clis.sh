#!/usr/bin/env bash
# Install ACP-capable CLIs (Cursor agent, GitHub Copilot). Used on control plane and runners.
# Usage: install-acp-clis.sh [/path/to/env-file]
set -euo pipefail

ENV_FILE="${1:-/etc/pmm-agentic-flow/env}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

cursor_ok=false
copilot_ok=false
copilot_attempted=false

echo "[acp-clis] installing ACP backends"

if bash "$REPO_ROOT/deploy/install-cursor-cli.sh"; then
  cursor_ok=true
else
  echo "[acp-clis] cursor install failed" >&2
fi

if [ -n "${GITHUB_COPILOT_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
  copilot_attempted=true
  if bash "$REPO_ROOT/deploy/install-copilot-cli.sh"; then
    copilot_ok=true
  else
    echo "[acp-clis] copilot install failed" >&2
  fi
fi

installed=()
[ -x /usr/local/bin/agent ] && installed+=("cursor:/usr/local/bin/agent")
[ -x /usr/local/bin/copilot ] && installed+=("copilot:/usr/local/bin/copilot")

if [ "${#installed[@]}" -gt 0 ]; then
  echo "[acp-clis] available: ${installed[*]}"
else
  echo "[acp-clis] WARNING: no ACP CLI installed"
fi

if [ -n "${CURSOR_API_KEY:-}" ] && [ ! -x /usr/local/bin/agent ] && [ ! -x /usr/local/bin/copilot ]; then
  echo "[acp-clis] ERROR: CURSOR_API_KEY is set but neither /usr/local/bin/agent nor /usr/local/bin/copilot is available." >&2
  if [ "$cursor_ok" = false ]; then
    echo "[acp-clis] ERROR: Cursor CLI install failed (CDN may return HTTP 403 from cloud IPs)." >&2
  fi
  if [ "$copilot_attempted" = false ]; then
    echo "[acp-clis] ERROR: Set GITHUB_COPILOT_TOKEN or GITHUB_TOKEN for Copilot ACP fallback." >&2
  elif [ "$copilot_ok" = false ]; then
    echo "[acp-clis] ERROR: Copilot CLI install also failed." >&2
  fi
  exit 1
fi
