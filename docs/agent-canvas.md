# Agent Canvas (OpenHands UI)

This stack uses **[Agent Canvas](https://docs.openhands.dev/openhands/usage/agent-canvas/setup)** — not the legacy Local GUI on port 3000.

## What runs in Docker

| Service | Image | Role |
|---------|-------|------|
| **agent-canvas** | `ghcr.io/openhands/agent-canvas:latest` | Browser UI + agent backend |
| **orchestrator** | built locally | Jira webhooks + loop API |
| **caddy** | TLS reverse proxy | `https://<linode-ip>/` |

## First login

1. Open `https://<linode-ip>/` (accept self-signed cert warning).
2. Enter **API key** = `AGENT_CANVAS_API_KEY` from `/etc/pmm-agentic-flow/env`.
3. **Manage Backends** — connect your LLM:
   - **GitHub Copilot:** Copilot CLI with `--acp` (no LiteLLM container needed).
   - **Anthropic / OpenAI:** provider API keys in Settings.
4. **Skills** — add project skills (replaces legacy microagents mount).

See [tokens-and-secrets.md](./tokens-and-secrets.md) for LLM options including Cursor.

## URL routing (Caddy)

| Path | Target |
|------|--------|
| `/` | Agent Canvas UI + backend |
| `/hooks/jira` | Orchestrator Jira webhook |
| `/loop/*` | Orchestrator API (e.g. `/loop/api/tickets/transition`) |

**Important:** Do not route `/api/*` to the orchestrator — that breaks Agent Canvas.

## Volume permissions

If Canvas logs JWT permission errors on `/.openhands-state/`:

```bash
bash scripts/fix-agent-canvas-volumes.sh 1000 deploy
docker compose --env-file ../.env restart agent-canvas
```

## Recover after bad deploy

```bash
bash scripts/linode-recover.sh
```
