#!/usr/bin/env bash
# Simulate a Jira status transition (POC without Jira admin).
set -euo pipefail

BASE_URL="${ORCHESTRATOR_BASE_URL:-https://127.0.0.1/orchestrator}"
API_KEY="${ORCHESTRATOR_API_KEY:?Set ORCHESTRATOR_API_KEY}"

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
