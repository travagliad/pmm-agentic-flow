#!/usr/bin/env bash
# Install Cursor CLI inside agent-canvas and wire CURSOR_API_KEY for ACP.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
COMPOSE="docker compose --env-file $ENV_FILE -f $ROOT/deploy/docker-compose.yml"
AGENT_BIN="/home/openhands/.local/bin/agent"
CONTAINER="agent-canvas"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "ERROR: $CONTAINER is not running. Start it first:"
  echo "  $COMPOSE up -d agent-canvas"
  exit 1
fi

install_cli() {
  if docker exec "$CONTAINER" test -x "$AGENT_BIN" 2>/dev/null; then
    echo "==> Cursor CLI already installed at $AGENT_BIN"
    docker exec "$CONTAINER" su -s /bin/bash openhands -c "$AGENT_BIN --version"
    return 0
  fi

  echo "==> Installing Cursor CLI inside $CONTAINER (user openhands)..."
  docker exec "$CONTAINER" su -s /bin/bash openhands -c \
    'curl -fsSL https://cursor.com/install | bash'

  docker exec "$CONTAINER" test -x "$AGENT_BIN"
  docker exec "$CONTAINER" su -s /bin/bash openhands -c "$AGENT_BIN --version"
}

ensure_api_key() {
  if [ -f "$ENV_FILE" ] && grep -q '^CURSOR_API_KEY=.\+' "$ENV_FILE" 2>/dev/null; then
    echo "==> CURSOR_API_KEY already set in $ENV_FILE"
    return 0
  fi

  echo ""
  echo "Cursor API key (uses your Cursor subscription — NOT OpenAI/Anthropic):"
  echo "  1. Open https://cursor.com/dashboard"
  echo "  2. Settings → API Keys → New API Key"
  echo "  3. Copy the key (shown once)"
  echo ""
  read -r -s -p "Paste CURSOR_API_KEY (Enter to skip and use agent login instead): " key
  echo ""

  if [ -z "$key" ]; then
    echo "==> Skipped — run login manually (see below)."
    return 0
  fi

  if grep -q '^CURSOR_API_KEY=' "$ENV_FILE" 2>/dev/null; then
    sed -i.bak "s|^CURSOR_API_KEY=.*|CURSOR_API_KEY=${key}|" "$ENV_FILE"
    rm -f "${ENV_FILE}.bak"
  else
    printf '\n# Cursor CLI (ACP backend)\nCURSOR_API_KEY=%s\n' "$key" >> "$ENV_FILE"
  fi
  echo "==> Saved CURSOR_API_KEY to $ENV_FILE"
}

login_interactive() {
  if [ -f "$ENV_FILE" ] && grep -q '^CURSOR_API_KEY=.\+' "$ENV_FILE" 2>/dev/null; then
    return 0
  fi
  echo ""
  echo "==> No API key — authenticate with browser (one-time):"
  echo "    docker exec -it $CONTAINER su -s /bin/bash openhands"
  echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo "    NO_OPEN_BROWSER=1 agent login"
  echo "    # open the printed URL on your laptop, then: agent status"
}

test_acp() {
  echo "==> Smoke test (agent status)..."
  if [ -f "$ENV_FILE" ] && grep -q '^CURSOR_API_KEY=.\+' "$ENV_FILE" 2>/dev/null; then
    # shellcheck disable=SC1090
    set -a && source "$ENV_FILE" && set +a
    docker exec -e CURSOR_API_KEY="${CURSOR_API_KEY:-}" "$CONTAINER" \
      su -s /bin/bash openhands -c "$AGENT_BIN status" || true
  else
    docker exec "$CONTAINER" su -s /bin/bash openhands -c \
      "export PATH=\"\$HOME/.local/bin:\$PATH\"; agent status" || true
  fi
}

install_cli
ensure_api_key

if grep -q '^CURSOR_API_KEY=.\+' "$ENV_FILE" 2>/dev/null; then
  echo "==> Recreating agent-canvas so it picks up CURSOR_API_KEY..."
  $COMPOSE up -d --force-recreate agent-canvas
  sleep 5
  install_cli
fi

test_acp
login_interactive

cat <<EOF

==> Next: configure in the Canvas UI (http://<ip>:8000)

1. Manage Backends → Add backend → Cursor (ACP)
   - Command: $AGENT_BIN
   - Args: acp
   - (If asked) auth: cursor_login or env CURSOR_API_KEY

2. Settings → set default LLM / provider to that Cursor backend

3. New conversation → send a test message

Re-run this script after 'docker compose recreate' (CLI lives in the container, not the volume).

EOF
