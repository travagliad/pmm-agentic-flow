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

fix_openhands_volumes() {
  local uid="${1:-1000}"
  local project="${2:-deploy}"
  for vol in "${project}_openhands-state" "${project}_openhands-workspace"; do
    if docker volume inspect "$vol" >/dev/null 2>&1; then
      echo "==> chown ${uid}:${uid} on volume $vol"
      docker run --rm -v "${vol}:/data" alpine:3.21 sh -c "mkdir -p /data && chown -R ${uid}:${uid} /data && chmod -R u+rwX /data"
    fi
  done
}

echo "==> Starting stack..."
cd "$DEST/deploy"
docker compose --env-file "$DEST/.env" pull
OH_UID="$(grep -E '^OPENHANDS_SANDBOX_USER_ID=' "$DEST/.env" | cut -d= -f2- || echo 1000)"
fix_openhands_volumes "$OH_UID" deploy
docker compose --env-file "$DEST/.env" up -d --build

echo ""
echo "==> Waiting up to 3 min for services (litellm → openhands → caddy)..."
for i in $(seq 1 36); do
  if curl -fsS "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
    echo "Orchestrator healthy."
    break
  fi
  if [ "$i" -eq 36 ]; then
    echo "WARN: stack not fully healthy yet — diagnostics:"
    docker compose --env-file "$DEST/.env" ps
    docker logs loop-litellm --tail 40 2>&1 || true
    docker logs loop-openhands --tail 40 2>&1 || true
    docker logs loop-caddy --tail 20 2>&1 || true
  fi
  sleep 5
done

echo ""
echo "==> docker ps"
docker ps

echo ""
echo "When healthy, open: https://$SSLIP_DOMAIN/"
echo "Health: curl -s localhost:8080/health"
