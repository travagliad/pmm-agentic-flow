#!/usr/bin/env bash
# Verify PUBLIC_IP (IPv4) is set before starting Caddy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

IP="${PUBLIC_IP:-$(bash "$ROOT/scripts/public-ip.sh")}"

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: PUBLIC_IP must be IPv4, got: $IP" >&2
  exit 1
fi

if [ -f "$ENV_FILE" ]; then
  grep -q '^PUBLIC_IP=' "$ENV_FILE" && sed -i "s|^PUBLIC_IP=.*|PUBLIC_IP=$IP|" "$ENV_FILE" \
    || echo "PUBLIC_IP=$IP" >> "$ENV_FILE"
fi

echo "PUBLIC_IP=$IP (Caddy TLS + https://$IP/)"
