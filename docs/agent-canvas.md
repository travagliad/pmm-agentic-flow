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

## Recover

```bash
bash scripts/linode-recover.sh
```
