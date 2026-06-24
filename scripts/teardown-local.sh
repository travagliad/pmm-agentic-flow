#!/usr/bin/env bash
# Remove the PMM Agentic Flow stack from THIS machine (local mistaken deploy).
# Production runs on Linode — see docs/deploy-linode.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/deploy"

if [ ! -f "$ROOT/.env" ]; then
  echo "No .env found — nothing to tear down via compose project."
else
  echo "Stopping loop-* containers and volumes..."
  docker compose --env-file "$ROOT/.env" down -v --remove-orphans
fi

echo ""
echo "Remaining containers (unrelated stacks are left alone):"
docker ps -a --format "table {{.Names}}\t{{.Status}}" | head -20
echo ""
echo "Done. Next: deploy on Linode → docs/deploy-linode.md"
