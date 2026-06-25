#!/usr/bin/env bash
# Simulate Jira webhook (same as moving a card) — run from PC or control plane.
set -euo pipefail

BASE_URL="${WEBHOOK_BASE_URL:-https://dismay-concierge-gem.ngrok-free.dev}"
SECRET="${JIRA_WEBHOOK_SECRET:-${ORCHESTRATOR_API_KEY:-}}"
TICKET="${1:?Usage: simulate-jira-webhook.sh PMM-12345 'In Progress' [summary]}"
STATUS="${2:?Usage: simulate-jira-webhook.sh PMM-12345 'In Progress' [summary]}"
SUMMARY="${3:-Simulated transition}"

if [ -z "$SECRET" ]; then
  echo "Set JIRA_WEBHOOK_SECRET (terraform api_secret)" >&2
  exit 1
fi

BODY=$(jq -n \
  --arg ticket "$TICKET" \
  --arg status "$STATUS" \
  --arg summary "$SUMMARY" \
  '{
    issue: {
      key: $ticket,
      fields: {
        summary: $summary,
        status: { name: $status }
      }
    }
  }')

curl -sS -X POST "${BASE_URL%/}/hooks/jira" \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: ${SECRET}" \
  -H "ngrok-skip-browser-warning: true" \
  -d "$BODY" | jq .
