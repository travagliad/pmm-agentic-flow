#!/usr/bin/env bash
# Run ON THE LINODE as root after SSH:
#   curl -fsSL https://raw.githubusercontent.com/travagliad/pmm-agentic-flow/master/scripts/linode-recover.sh | bash
# Or copy this file and run: bash linode-recover.sh
set -euo pipefail

PUBLIC_IP="$(curl -fsSL https://ifconfig.me/ip 2>/dev/null || hostname -I | awk '{print $1}')"
SSLIP_DOMAIN="${PUBLIC_IP//./-}.sslip.io"

echo "==> Detected IP: $PUBLIC_IP"
echo "==> sslip.io hostname: $SSLIP_DOMAIN"

if [ -f /var/log/pmm-agentic-flow-bootstrap.log ]; then
  echo "==> Last 40 lines of bootstrap log:"
  tail -40 /var/log/pmm-agentic-flow-bootstrap.log
fi

DEST=/opt/pmm-agentic-flow/src
ENV_FILE=/etc/pmm-agentic-flow/env

if [ ! -d "$DEST/.git" ]; then
  echo "==> Repo missing — cloning..."
  mkdir -p /opt/pmm-agentic-flow
  git clone https://github.com/travagliad/pmm-agentic-flow.git "$DEST"
fi

if [ -f "$ENV_FILE" ]; then
  sed -i "s|^LOOP_DOMAIN=.*|LOOP_DOMAIN=$SSLIP_DOMAIN|" "$ENV_FILE"
  sed -i "s|^OPENHANDS_PUBLIC_URL=.*|OPENHANDS_PUBLIC_URL=https://$SSLIP_DOMAIN|" "$ENV_FILE"
  cp "$ENV_FILE" "$DEST/.env"
else
  echo "ERROR: $ENV_FILE missing — cloud-init may have failed. Create it from terraform secrets."
  exit 1
fi

echo "==> Starting stack..."
cd "$DEST/deploy"
docker compose --env-file "$DEST/.env" pull
docker compose --env-file "$DEST/.env" up -d --build

echo ""
echo "==> docker ps"
docker ps

echo ""
echo "When healthy, open: https://$SSLIP_DOMAIN/"
echo "Health: curl -s localhost:8080/health"
