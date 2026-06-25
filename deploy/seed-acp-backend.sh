#!/usr/bin/env bash
# Register the available ACP CLI in Agent Canvas settings (PATCH /api/settings).
# Settings persist in ~/.openhands/settings.json (agentcanvas user).
# Usage: seed-acp-backend.sh [/path/to/env-file]
set -euo pipefail

ENV_FILE="${1:-/etc/pmm-agentic-flow/env}"
CANVAS_URL="${AGENT_CANVAS_BASE_URL:-http://127.0.0.1:8000}"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

API_KEY="${LOCAL_BACKEND_API_KEY:-${AGENT_CANVAS_API_KEY:-}}"
if [ -z "$API_KEY" ]; then
  echo "[seed-acp] WARNING: LOCAL_BACKEND_API_KEY unset; skipping auto-seed" >&2
  exit 0
fi

if [ -n "${CURSOR_API_KEY:-}" ] && [ ! -x /usr/local/bin/agent ]; then
  echo "[seed-acp] ERROR: CURSOR_API_KEY is set but /usr/local/bin/agent is missing" >&2
  exit 1
fi

if [ -x /usr/local/bin/agent ]; then
  CLI_BIN=/usr/local/bin/agent
  CLI_LABEL=Cursor
elif [ -x /usr/local/bin/copilot ]; then
  CLI_BIN=/usr/local/bin/copilot
  CLI_LABEL=Copilot
else
  echo "[seed-acp] WARNING: no ACP CLI at /usr/local/bin/agent or /usr/local/bin/copilot" >&2
  exit 0
fi

settings_json=""
for _ in $(seq 1 30); do
  settings_json="$(curl -sf -H "X-Session-API-Key: $API_KEY" "$CANVAS_URL/api/settings" 2>/dev/null || true)"
  if [ -n "$settings_json" ]; then
    break
  fi
  sleep 2
done
if [ -z "$settings_json" ]; then
  echo "[seed-acp] ERROR: GET $CANVAS_URL/api/settings failed (is agent-canvas running?)" >&2
  exit 1
fi

current_cmd="$(printf '%s' "$settings_json" | jq -r '.agent_settings.acp_command // [] | join(" ")')"
current_args="$(printf '%s' "$settings_json" | jq -r '.agent_settings.acp_args // [] | join(" ")')"
expected_cmd="$CLI_BIN"
expected_args="acp"

if [ "$current_cmd" = "$expected_cmd" ] && [ "$current_args" = "$expected_args" ]; then
  echo "[seed-acp] already configured: $CLI_BIN acp ($CLI_LABEL)"
  exit 0
fi

if [ "$CLI_LABEL" = Copilot ] && [ ! -x /usr/local/bin/agent ]; then
  echo "[seed-acp] Cursor agent missing; seeding Copilot ACP backend"
elif [ "$CLI_LABEL" = Cursor ]; then
  echo "[seed-acp] seeding Cursor ACP backend"
else
  echo "[seed-acp] seeding $CLI_LABEL ACP backend"
fi

payload="$(jq -n \
  --arg bin "$CLI_BIN" \
  '{
    agent_settings_diff: {
      agent_kind: "acp",
      acp_server: "custom",
      acp_command: [$bin],
      acp_args: ["acp"]
    }
  }')"

if curl -sf -X PATCH "$CANVAS_URL/api/settings" \
  -H "Content-Type: application/json" \
  -H "X-Session-API-Key: $API_KEY" \
  -d "$payload" >/dev/null; then
  echo "[seed-acp] configured ACP: $CLI_BIN acp ($CLI_LABEL)"
else
  echo "[seed-acp] ERROR: PATCH $CANVAS_URL/api/settings failed" >&2
  exit 1
fi
