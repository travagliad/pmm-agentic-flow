#!/usr/bin/env bash
# Refresh GitHub Copilot token for LiteLLM (github/* models).
# Requires: curl, jq, gh (logged in) OR manual token in GITHUB_COPILOT_TOKEN
set -euo pipefail

if [ -n "${GITHUB_COPILOT_TOKEN:-}" ]; then
  echo "GITHUB_COPILOT_TOKEN already set in environment."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Install GitHub CLI (gh) and run 'gh auth login', or set GITHUB_COPILOT_TOKEN manually."
  exit 1
fi

# Device-flow token used by LiteLLM github provider
TOKEN=$(gh auth token)
export GITHUB_COPILOT_TOKEN="$TOKEN"
echo "Exported GITHUB_COPILOT_TOKEN from gh auth token."
echo "Add to .env: GITHUB_COPILOT_TOKEN=$TOKEN"
