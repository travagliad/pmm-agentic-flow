#!/usr/bin/env bash
# LOCAL ONLY — do not use for PMM POC. See docs/GETTING-STARTED.md (Linode path).
set -euo pipefail

echo "ERROR: This script runs Docker on YOUR machine." >&2
echo "For the real setup use Terraform + Linode:" >&2
echo "  docs/GETTING-STARTED.md" >&2
echo "" >&2
read -r -p "Continue anyway for local dev? [y/N] " ans
if [ "${ans:-n}" != "y" ] && [ "${ans:-n}" != "Y" ]; then
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/deploy"

if [ ! -f "$ROOT/.env" ]; then
  cp "$ROOT/.env.example" "$ROOT/.env"
  echo "Created .env from .env.example — fill in secrets before continuing."
  exit 1
fi

docker compose --env-file "$ROOT/.env" pull
docker compose --env-file "$ROOT/.env" up -d --build

echo "Stack up. OpenHands UI via Caddy at https://${LOOP_DOMAIN:-your-domain}"
