#!/usr/bin/env bash
# Open TCP 8000 + 8080 on the Linode Cloud Firewall (not ufw).
# Run on the VM as root — needs LINODE_TOKEN in /etc/pmm-agentic-flow/env
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/pmm-agentic-flow/env}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

TOKEN="${LINODE_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  echo "ERROR: LINODE_TOKEN not set in $ENV_FILE" >&2
  exit 1
fi

api() {
  curl -fsS -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "$@"
}

PUBLIC_IP="$(curl -4 -fsSL https://ifconfig.me/ip 2>/dev/null || hostname -I | awk '{print $1}')"
echo "==> Public IPv4: $PUBLIC_IP"

INSTANCE_ID="${LINODE_INSTANCE_ID:-}"
if [ -z "$INSTANCE_ID" ]; then
  INSTANCE_ID="$(api "https://api.linode.com/v4/linode/instances?page_size=100" \
    | jq -r --arg ip "$PUBLIC_IP" '.data[] | select(.ipv4[]? == $ip) | .id' | head -1)"
fi

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
  echo "ERROR: Could not find Linode instance for IP $PUBLIC_IP" >&2
  echo "Set LINODE_INSTANCE_ID in $ENV_FILE and retry." >&2
  exit 1
fi
echo "==> Instance ID: $INSTANCE_ID"

FW_ID="$(api "https://api.linode.com/v4/networking/firewalls?page_size=100" \
  | jq -r --argjson id "$INSTANCE_ID" '
    .data[] | select(.entities[]? | .id == $id and .type == "linode") | .id' | head -1)"

if [ -z "$FW_ID" ] || [ "$FW_ID" = "null" ]; then
  echo "WARN: No Cloud Firewall attached to this instance."
  echo "      Check Linode Cloud Manager → Firewalls, or disable firewall on the instance."
  echo "      ufw status:"
  ufw status 2>/dev/null || true
  exit 0
fi
echo "==> Firewall ID: $FW_ID"

RULES="$(api "https://api.linode.com/v4/networking/firewalls/$FW_ID/rules")"

NEED_8000="$(echo "$RULES" | jq '[.inbound[]? | select(.ports == "8000" and .action == "ACCEPT")] | length')"
NEED_8080="$(echo "$RULES" | jq '[.inbound[]? | select(.ports == "8080" and .action == "ACCEPT")] | length')"

if [ "$NEED_8000" != "0" ] && [ "$NEED_8080" != "0" ]; then
  echo "==> Ports 8000 and 8080 already allowed in Cloud Firewall."
  exit 0
fi

NEW_INBOUND="$(echo "$RULES" | jq '.inbound // []')"
if [ "$NEED_8000" = "0" ]; then
  echo "==> Adding inbound TCP 8000"
  NEW_INBOUND="$(echo "$NEW_INBOUND" | jq '. + [{
    "label": "allow-agent-canvas",
    "action": "ACCEPT",
    "protocol": "TCP",
    "ports": "8000",
    "addresses": {"ipv4": ["0.0.0.0/0"]}
  }]')"
fi
if [ "$NEED_8080" = "0" ]; then
  echo "==> Adding inbound TCP 8080"
  NEW_INBOUND="$(echo "$NEW_INBOUND" | jq '. + [{
    "label": "allow-orchestrator",
    "action": "ACCEPT",
    "protocol": "TCP",
    "ports": "8080",
    "addresses": {"ipv4": ["0.0.0.0/0"]}
  }]')"
fi

BODY="$(echo "$RULES" | jq --argjson inbound "$NEW_INBOUND" '{
  inbound: $inbound,
  outbound: (.outbound // []),
  inbound_policy: (.inbound_policy // "DROP"),
  outbound_policy: (.outbound_policy // "ACCEPT")
}')"

api -X PUT -d "$BODY" "https://api.linode.com/v4/networking/firewalls/$FW_ID/rules" >/dev/null

echo "==> Cloud Firewall updated."
echo "    Try: http://$PUBLIC_IP:8000/"
