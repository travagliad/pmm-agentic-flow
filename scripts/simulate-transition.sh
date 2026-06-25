#!/usr/bin/env bash
# Simulate a Jira status transition (POC without Jira admin).
set -euo pipefail

BASE_URL="${ORCHESTRATOR_BASE_URL:-http://127.0.0.1:8080/orchestrator}"
API_KEY="${ORCHESTRATOR_API_KEY:-${JIRA_WEBHOOK_SECRET:-}}"
if [ -z "$API_KEY" ]; then
  echo "Set ORCHESTRATOR_API_KEY or JIRA_WEBHOOK_SECRET (terraform api_secret)" >&2
  exit 1
fi

TICKET="${1:?Usage: simulate-transition.sh PMM-12345 'In Progress' [summary]}"
STATUS="${2:?Usage: simulate-transition.sh PMM-12345 'In Progress' [summary]}"
SUMMARY="${3:-}"

BODY=$(jq -n \
  --arg ticket "$TICKET" \
  --arg status "$STATUS" \
  --arg summary "$SUMMARY" \
  '{ticketKey:$ticket, statusName:$status, summary: (if $summary=="" then null else $summary end)}')

curl -sS -X POST "${BASE_URL%/}/tickets/transition" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -d "$BODY" | jq .
