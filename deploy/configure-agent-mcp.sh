#!/usr/bin/env bash
# Atlassian Rovo MCP via API token (headless) — not OAuth UI.
# https://support.atlassian.com/atlassian-rovo-mcp-server/docs/configuring-authentication-via-api-token/
# Requires org admin: enable API token auth + Rovo MCP scoped token for the user.
set -euo pipefail

ENV_FILE="${1:-/etc/pmm-agentic-flow/env}"
AGENT_USER="${AGENT_USER:-agentcanvas}"
AGENT_HOME="/home/${AGENT_USER}"
MCP_FILE="${AGENT_HOME}/.openhands/mcp.json"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

if [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_API_TOKEN:-}" ]; then
  echo "[configure-agent-mcp] SKIP Atlassian MCP — JIRA_EMAIL or JIRA_API_TOKEN unset"
  exit 0
fi

if ! id "$AGENT_USER" >/dev/null 2>&1; then
  echo "[configure-agent-mcp] SKIP — user $AGENT_USER missing"
  exit 0
fi

AUTH_B64=$(printf '%s' "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64 -w0 2>/dev/null || printf '%s' "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)

mkdir -p "${AGENT_HOME}/.openhands"

if [ -f "$MCP_FILE" ]; then
  cp "$MCP_FILE" "${MCP_FILE}.bak.$(date +%s)" 2>/dev/null || true
fi

# mcp-remote + Authorization header - works when OAuth UI is not available (ACP headless).
cat >"$MCP_FILE" <<EOF
{
  "mcpServers": {
    "atlassian-rovo-mcp": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@latest",
        "https://mcp.atlassian.com/v1/mcp",
        "--header",
        "Authorization: Basic ${AUTH_B64}"
      ]
    }
  }
}
EOF

chown -R "${AGENT_USER}:${AGENT_USER}" "${AGENT_HOME}/.openhands"
chmod 0600 "$MCP_FILE"
echo "[configure-agent-mcp] wrote ${MCP_FILE} (atlassian-rovo-mcp via API token)"
