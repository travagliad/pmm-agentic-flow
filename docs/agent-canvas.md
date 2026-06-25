# Agent Canvas

Stack: **agent-canvas** on `:8000` + **orchestrator** on `:8080`. No Caddy.

## Open

```text
http://<linode-ip>:8000/
```

Enter `AGENT_CANVAS_API_KEY` from `/etc/pmm-agentic-flow/env`.

## Orchestrator (Jira + API)

| URL | Purpose |
|-----|---------|
| `http://<ip>:8080/hooks/jira` | Jira webhook |
| `http://<ip>:8080/orchestrator/tickets/transition` | Manual transitions (`x-api-key`) |

## LLM backends

Manage Backends in the UI — Cursor/Copilot via ACP. See [llm-acp.md](./llm-acp.md).

## Manage Backends shows Disconnected (502 / 127.0.0.1:18000)

The UI on `:8000` is only the frontend. The **agent-server** runs internally on `:18000`. If it crashed (often SQLite/volume permissions), you see Disconnected.

```bash
docker exec agent-canvas wget -qO- http://127.0.0.1:18000/health   # must succeed
bash scripts/reset-agent-canvas.sh   # if not
cd deploy && docker compose --env-file ../.env up -d --force-recreate agent-canvas
```

Do **not** add a separate backend URL in Manage Backends when using the full stack on the same VM — just enter `AGENT_CANVAS_API_KEY` when prompted. The built-in Local backend uses the internal proxy.

Ensure `AGENT_CANVAS_PUBLIC_URL` in env matches how you open the site (e.g. `http://139.162.150.187:8000`).

```bash
bash scripts/linode-recover.sh
```
