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

The UI on `:8000` is only the frontend. The **agent-server** runs internally on `:18000`. If it crashed or **hangs** (wget/curl never returns), you see Disconnected.

```bash
# :18000 hung? hard restart (keeps volume)
bash scripts/restart-agent-canvas.sh

docker exec agent-canvas wget -qO- --timeout=5 http://127.0.0.1:18000/health   # must succeed in ~1s
bash scripts/reset-agent-canvas.sh   # if permissions/SQLite corrupt
cd deploy && docker compose --env-file ../.env up -d --force-recreate agent-canvas
```

On a **4GB** Linode, a long conversation or ACP subprocess can stall the agent-server until restart. Check `free -h` and `dmesg | grep -i kill` for OOM.

### Overnight / hung :18000 (health logs stop)

When `docker logs` only shows old `GET /health` lines and nothing recent, the agent-server is **stuck** — the browser shows `signal timed out`.

```bash
bash scripts/restart-agent-canvas.sh
```

Auto-recover every 5 minutes (on the Linode):

```bash
chmod +x /opt/pmm-agentic-flow/src/scripts/agent-canvas-watchdog.sh
( crontab -l 2>/dev/null; echo '*/5 * * * * /opt/pmm-agentic-flow/src/scripts/agent-canvas-watchdog.sh >> /var/log/agent-canvas-watchdog.log 2>&1' ) | crontab -
```

Do **not** add a separate backend URL in Manage Backends when using the full stack on the same VM — just enter `AGENT_CANVAS_API_KEY` when prompted. The built-in Local backend uses the internal proxy.

Ensure `AGENT_CANVAS_PUBLIC_URL` in env matches how you open the site (e.g. `http://139.162.150.187:8000`).

```bash
bash scripts/linode-recover.sh
```
