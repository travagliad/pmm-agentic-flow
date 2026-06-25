# Agent Canvas

Stack: **agent-canvas** on `:8000` + **orchestrator** on `:8080`. Runs on the Linode VM only.

Secrets: `/etc/pmm-agentic-flow/env` (from `terraform.tfvars` via cloud-init).

## Open

```text
http://<linode-ip>:8000/
```

API key: `grep AGENT_CANVAS_API_KEY /etc/pmm-agentic-flow/env`

## LLM backends

Cursor + Copilot CLIs install automatically on container start. See [llm-acp.md](./llm-acp.md).

## Troubleshooting

```bash
docker logs agent-canvas --tail 80
cd /opt/pmm-agentic-flow/src/deploy
docker compose --env-file /etc/pmm-agentic-flow/env up -d --force-recreate agent-canvas
```

## Re-deploy after git pull

```bash
cd /opt/pmm-agentic-flow/src && git pull
cd deploy
docker compose --env-file /etc/pmm-agentic-flow/env run --rm agent-canvas-init
docker compose --env-file /etc/pmm-agentic-flow/env up -d --build --remove-orphans
```
