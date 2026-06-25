#!/usr/bin/env bash
# Jira credentials readable by agentcanvas (main env stays root-only).
set -euo pipefail

MAIN_ENV="${1:-/etc/pmm-agentic-flow/env}"
JIRA_ENV="/etc/pmm-agentic-flow/agent-shell.env"
AGENT_USER="${AGENT_USER:-agentcanvas}"

if [ ! -f "$MAIN_ENV" ]; then
  echo "[install-jira-agent-env] SKIP — $MAIN_ENV missing" >&2
  exit 0
fi

if ! id "$AGENT_USER" >/dev/null 2>&1; then
  echo "[install-jira-agent-env] SKIP — user $AGENT_USER missing" >&2
  exit 0
fi

grep -E '^(JIRA_BASE_URL|JIRA_EMAIL|JIRA_API_TOKEN|GITHUB_TOKEN)=' "$MAIN_ENV" >"$JIRA_ENV"
chown root:"$AGENT_USER" "$JIRA_ENV"
chmod 640 "$JIRA_ENV"
echo "[install-jira-agent-env] wrote $JIRA_ENV (640 root:$AGENT_USER)"
