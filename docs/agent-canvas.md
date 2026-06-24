# Agent Canvas (current OpenHands UI)

This stack uses **[Agent Canvas](https://docs.openhands.dev/openhands/usage/agent-canvas/setup)** — not the legacy Local GUI (`ghcr.io/all-hands-ai/openhands:0.39` on port 3000).

## What runs in Docker

| Service | Image | Port | Role |
|---------|-------|------|------|
| **agent-canvas** | `ghcr.io/openhands/agent-canvas:latest` | 8000 | Browser UI + agent backend |
| **litellm** | optional proxy | 4000 | GitHub Copilot via OpenAI-compatible API |
| **orchestrator** | built locally | 8080 | Jira webhooks + loop API |
| **caddy** | TLS reverse proxy | 443 | Public entrypoint |

Official reference: [VM / Self-Hosted Installation](https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm) and [Docker Backend](https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/docker).

## First login

1. Open `https://<your-domain>/` (e.g. `https://139-162-150-187.sslip.io/`).
2. Enter **API key** = `AGENT_CANVAS_API_KEY` from `/etc/pmm-agentic-flow/env` (same as `LOCAL_BACKEND_API_KEY` inside the container).
3. **Settings → LLM** — configure your provider:
   - **LiteLLM (Copilot POC):** Base URL `http://litellm:4000` only works from inside the Docker network; from the UI use the public proxy or configure provider keys directly.
   - For VM self-host, simplest POC: set provider API key in Settings (Anthropic/OpenAI) or point at an OpenAI-compatible endpoint you control.
4. **Customize** — add Skills (replaces legacy `agents/microagents/` mount for V0 OpenHands).

## LiteLLM + Copilot (optional)

LiteLLM stays in the stack for teams that want Copilot-backed models. After Agent Canvas is up, create an LLM profile in the UI with:

- Provider: OpenAI-compatible / custom base URL (depends on Canvas version)
- Base URL: internal `http://127.0.0.1:4000` is **not** reachable from the browser — use provider keys in Settings for POC, or expose LiteLLM via a separate route later.

## URL routing (Caddy)

| Path | Target |
|------|--------|
| `/` | Agent Canvas UI + backend (`/api/*` belongs to Canvas) |
| `/hooks/jira` | Orchestrator Jira webhook |
| `/loop/*` | Orchestrator API (e.g. `/loop/health`, `/loop/api/tickets/transition`) |

**Important:** The old config routed `/api/*` to the orchestrator, which breaks Agent Canvas.

## Orchestrator ↔ Agent Canvas

The orchestrator still uses the legacy `/api/v1/app-conversations` client for Jira-driven automation. Agent Canvas may expose a different API surface — **programmatic Jira loop integration is a known gap** until the client is updated to the Agent Canvas backend API.

Manual agent work in the browser is fully supported today.

## Migrate from legacy OpenHands 0.39 on Linode

```bash
cd /opt/pmm-agentic-flow/src
git pull

# Add new secrets (keep existing tokens)
grep -q AGENT_CANVAS_API_KEY /etc/pmm-agentic-flow/env || \
  echo "AGENT_CANVAS_API_KEY=$(openssl rand -hex 24)" >> /etc/pmm-agentic-flow/env
grep -q AGENT_CANVAS_SECRET_KEY /etc/pmm-agentic-flow/env || \
  echo "AGENT_CANVAS_SECRET_KEY=$(openssl rand -hex 24)" >> /etc/pmm-agentic-flow/env
sed -i '/^OPENHANDS_VERSION=/d;/^AGENT_SERVER/d;/^OPENHANDS_SANDBOX/d' /etc/pmm-agentic-flow/env
echo 'AGENT_CANVAS_VERSION=latest' >> /etc/pmm-agentic-flow/env
cp /etc/pmm-agentic-flow/env .env

cd deploy
docker compose --env-file ../.env down
docker compose --env-file ../.env pull
bash ../scripts/fix-agent-canvas-volumes.sh
docker compose --env-file ../.env up -d --build
docker ps
```

Old volumes (`deploy_openhands-state`) are unused; safe to remove after confirming the new stack works.
