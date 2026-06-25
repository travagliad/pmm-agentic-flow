# Sandbox lifecycle — control plane + QA workers

## Architecture

```text
Control plane (4GB, always on)     https://<ip>/
  Caddy :443 → Agent Canvas + orchestrator (/hooks, /loop)

QA worker (8GB, per ticket)          https://<worker-ip>:8443/
  Created on In QA, destroyed on Ready for Merge
```

## Flow

| Jira status | Infra | Chat |
|-------------|-------|------|
| In Progress | Control plane only | `/opsx:apply` — local build, no PMM FB |
| In Review | — | Notice + FB tag sync |
| In QA | Create 8GB worker | `/loop:qa` when PMM up |
| Ready for Merge | Destroy worker | finalize + archive |

## Deploy / update (existing Linode)

```bash
cd /opt/pmm-agentic-flow/src && git pull
PUBLIC_IP=$(bash scripts/public-ip.sh)
sed -i "s|^AGENT_CANVAS_PUBLIC_URL=.*|AGENT_CANVAS_PUBLIC_URL=https://$PUBLIC_IP|" /etc/pmm-agentic-flow/env
cp /etc/pmm-agentic-flow/env .env
cd deploy && docker compose --env-file ../.env up -d --build
```

Open **https://\<your-ip\>/** (accept self-signed cert).

## Jira webhook

```text
POST https://<control-ip>/hooks/jira
Header: x-webhook-secret: <JIRA_WEBHOOK_SECRET>
```

## Test without Jira

```bash
export ORCHESTRATOR_API_KEY=...
export LOOP_BASE_URL=https://<control-ip>/loop

./scripts/simulate-transition.sh PMM-15083 "In Progress" "Summary"
./scripts/simulate-transition.sh PMM-15083 "In QA"
```

## Instance sizes

| Role | Linode type | RAM |
|------|-------------|-----|
| Control plane | `g6-standard-4` | 4GB |
| QA worker | `g6-standard-8` | 8GB |

Set in `terraform.tfvars`: `instance_type` vs `worker_linode_type`.

See also [tokens-and-secrets.md](./tokens-and-secrets.md).
