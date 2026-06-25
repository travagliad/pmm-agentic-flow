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

echo "[acp-clis] installing ACP backends"

if ! bash "$REPO_ROOT/deploy/install-cursor-cli.sh"; then
  echo "[acp-clis] cursor install failed" >&2
fi

if [ -n "${GITHUB_COPILOT_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
  if ! bash "$REPO_ROOT/deploy/install-copilot-cli.sh"; then
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

if [ -n "${CURSOR_API_KEY:-}" ]; then
  if ! { [ -x /usr/local/bin/agent ] && /usr/local/bin/agent --version >/dev/null 2>&1; }; then
    echo "[acp-clis] ERROR: CURSOR_API_KEY is set but /usr/local/bin/agent is missing or broken." >&2
    exit 1
  fi
fi

if [ ! -x /usr/local/bin/agent ] && [ ! -x /usr/local/bin/copilot ]; then
  echo "[acp-clis] ERROR: no ACP CLI installed." >&2
  exit 1
fi
