#!/usr/bin/env bash
# Fetch Jira issue via REST API (no Rovo MCP — org does not allow it).
# Usage: jira-issue.sh PMM-15167 [field...]
# Credentials: JIRA_* env vars, or /etc/pmm-agentic-flow/jira.env (agentcanvas-readable)
set -euo pipefail

load_env() {
  local file="$1"
  if [ -r "$file" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$file"
    set +a
    return 0
  fi
  return 1
}

if [ -z "${JIRA_BASE_URL:-}" ] || [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_API_TOKEN:-}" ]; then
  for candidate in \
    "${JIRA_ENV_FILE:-}" \
    /etc/pmm-agentic-flow/jira.env \
    /etc/pmm-agentic-flow/env; do
    [ -n "$candidate" ] || continue
    load_env "$candidate" && break
  done
fi

KEY="${1:?Usage: jira-issue.sh PMM-12345 [summary,description,...]}"
shift || true

if [ -z "${JIRA_BASE_URL:-}" ] || [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_API_TOKEN:-}" ]; then
  echo "Jira credentials missing. Run as root on CP: bash deploy/install-jira-agent-env.sh" >&2
  echo "Or set JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN in the environment." >&2
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
