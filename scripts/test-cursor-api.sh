#!/usr/bin/env bash
# Verify CURSOR_API_KEY against Cursor Cloud Agents API.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

if [ -z "${CURSOR_API_KEY:-}" ]; then
  echo "ERROR: CURSOR_API_KEY not set."
  echo "Add to $ENV_FILE or export CURSOR_API_KEY=crsr_..."
  echo "Get key: https://cursor.com/dashboard → Settings → API Keys"
  exit 1
fi

echo "==> GET /v1/me"
me="$(curl -fsS -u "${CURSOR_API_KEY}:" https://api.cursor.com/v1/me)"
echo "$me" | (command -v jq >/dev/null && jq . || cat)

echo ""
echo "==> GET /v1/models (first 5)"
models="$(curl -fsS -u "${CURSOR_API_KEY}:" 'https://api.cursor.com/v1/models?limit=5')"
echo "$models" | (command -v jq >/dev/null && jq . || cat)

echo ""
echo "Cursor API key OK. See docs/cursor-api.md to launch agents."
