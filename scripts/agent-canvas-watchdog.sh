#!/usr/bin/env bash
# Cron-friendly watchdog: restart agent-canvas when :18000 stops responding.
# Install: (crontab -l 2>/dev/null; echo '*/5 * * * * /opt/pmm-agentic-flow/src/scripts/agent-canvas-watchdog.sh >> /var/log/agent-canvas-watchdog.log 2>&1') | crontab -
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
LOG_PREFIX="[agent-canvas-watchdog $(date -Is)]"

if ! docker ps --format '{{.Names}}' | grep -qx agent-canvas; then
  echo "$LOG_PREFIX container missing — starting stack"
  docker compose --env-file "$ENV_FILE" -f "$ROOT/deploy/docker-compose.yml" up -d agent-canvas
  exit 0
fi

if docker exec agent-canvas wget -qO- --timeout=8 http://127.0.0.1:18000/health >/dev/null 2>&1 \
  && curl -fsS --connect-timeout 8 http://127.0.0.1:8000/health >/dev/null 2>&1; then
  exit 0
fi

echo "$LOG_PREFIX :18000 or :8000/health failed — restarting agent-canvas"
exec bash "$ROOT/scripts/restart-agent-canvas.sh"
