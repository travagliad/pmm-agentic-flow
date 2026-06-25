# Sandbox lifecycle

## 3 containers only

| Container | Role |
|-----------|------|
| `caddy` | HTTPS on `:443` → Canvas + orchestrator |
| `agent-canvas` | Chat UI + agent |
| `orchestrator` | Jira webhooks + ticket API |

Legacy `loop-litellm`, `loop-openhands` (0.39) are **not** part of the stack. Remove with:

```bash
bash scripts/stack-cleanup.sh
docker compose up -d --build
```

## URLs

```text
https://<ipv4>/                      Agent Canvas
https://<ipv4>/hooks/jira            Jira webhook
https://<ipv4>/orchestrator/tickets  API (x-api-key)
```

IPv4 only — `scripts/public-ip.sh` uses `curl -4`.

## Instance sizes (single source)

`config/stack.yaml` → `infrastructure.linode`:

| Role | Key | Default |
|------|-----|---------|
| Control plane | `control_plane_type` | `g6-standard-4` (4GB) |
| QA worker | `worker_type` | `g6-standard-8` (8GB) |

Terraform `instance_type` / `worker_linode_type` must match when provisioning the control plane VM.

## Update existing Linode

```bash
cd /opt/pmm-agentic-flow/src && git pull
bash scripts/stack-cleanup.sh
bash scripts/linode-recover.sh
```
