#!/usr/bin/env bash
# Tear down a mistaken local docker compose run (no .env required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/deploy"

echo "==> Stopping local agentic-flow compose project..."
docker compose -p agentic-flow down -v --remove-orphans 2>/dev/null || \
  docker compose down -v --remove-orphans 2>/dev/null || true

echo "==> Remaining containers:"
docker ps -a --format 'table {{.Names}}\t{{.Status}}'
