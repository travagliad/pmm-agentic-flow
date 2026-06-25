#!/usr/bin/env bash
# Optional: install agent CLIs for ACP backends (Cursor / Copilot).
# NOT required for the web UI to load — run after the stack is up.
set -euo pipefail

echo "==> Agent CLIs are optional (only needed for Manage Backends → ACP)."
echo "    The site works without them."

if command -v agent >/dev/null 2>&1; then
  echo "==> Cursor agent CLI already installed: $(command -v agent)"
else
  echo "==> Cursor agent CLI not found."
  echo "    Install: https://cursor.com/docs/cli/overview"
  echo "    Then: agent login  OR  export CURSOR_API_KEY=..."
  echo "    ACP mode: agent acp"
fi

if command -v copilot >/dev/null 2>&1; then
  echo "==> GitHub Copilot CLI already installed: $(command -v copilot)"
else
  echo "==> Copilot CLI not found."
  echo "    Install: https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli"
  echo "    Then: copilot login"
  echo "    ACP mode: copilot acp (if your version supports it)"
fi

echo ""
echo "Configure in Agent Canvas → Manage Backends. See docs/llm-acp.md"
