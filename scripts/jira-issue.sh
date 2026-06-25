#!/usr/bin/env bash
# Fetch Jira issue via REST API (no Rovo MCP — org does not allow it).
# Usage: jira-issue.sh PMM-15167 [field...]
# Credentials: JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN from env or /etc/pmm-agentic-flow/env
set -euo pipefail

ENV_FILE="${JIRA_ENV_FILE:-/etc/pmm-agentic-flow/env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

KEY="${1:?Usage: jira-issue.sh PMM-12345}"
shift || true

if [ -z "${JIRA_BASE_URL:-}" ] || [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_API_TOKEN:-}" ]; then
  echo "Set JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN (terraform tfvars -> /etc/pmm-agentic-flow/env)" >&2
  exit 1
fi

BASE="${JIRA_BASE_URL%/}"
AUTH=$(printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64 -w0 2>/dev/null || printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64)

if [ $# -gt 0 ]; then
  FIELDS=$(IFS=,; echo "$*")
  URL="${BASE}/rest/api/3/issue/${KEY}?fields=${FIELDS}"
else
  URL="${BASE}/rest/api/3/issue/${KEY}"
fi

curl -sS -f \
  -H "Authorization: Basic ${AUTH}" \
  -H "Accept: application/json" \
  "$URL"
