#!/usr/bin/env bash
# Simulate a Jira status transition (POC without Jira admin).
set -euo pipefail

BASE_URL="${LOOP_BASE_URL:-http://127.0.0.1:8080}"
API_KEY="${ORCHESTRATOR_API_KEY:?Set ORCHESTRATOR_API_KEY}"

TICKET="${1:?Usage: simulate-transition.sh PMM-12345 'In Progress' [summary]}"
STATUS="${2:?Usage: simulate-transition.sh PMM-12345 'In Progress' [summary]}"
SUMMARY="${3:-}"

BODY=$(jq -n \
  --arg ticket "$TICKET" \
  --arg status "$STATUS" \
  --arg summary "$SUMMARY" \
  '{ticketKey:$ticket, statusName:$status, summary: (if $summary=="" then null else $summary end)}')

curl -sS -X POST "${BASE_URL}/api/tickets/transition" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -d "$BODY" | jq .
