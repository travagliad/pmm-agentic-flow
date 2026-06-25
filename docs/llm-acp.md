# LLM backends via ACP (Agent Client Protocol)

Agent Canvas supports external agent backends over **ACP** — JSON-RPC 2.0 on stdio.

No LiteLLM container in this stack. **No OpenAI/Anthropic key required** if you use Cursor.

## Cursor on the Linode (recommended)

The ACP process runs **inside** the `agent-canvas` container (not on the host).

### One-shot setup

```bash
cd /opt/pmm-agentic-flow/src
git pull
bash scripts/setup-cursor-acp.sh
```

The script:

1. Installs `agent` CLI inside the container (`/home/openhands/.local/bin/agent`)
2. Prompts for `CURSOR_API_KEY` (or explains browser login)
3. Recreates `agent-canvas` so the key is in the container env

### Get a Cursor API key

Uses your **Cursor subscription** — not OpenAI/Anthropic:

1. https://cursor.com/dashboard
2. **Settings** → **API Keys** → **New API Key**
3. Copy once → add to `/opt/pmm-agentic-flow/src/.env` as `CURSOR_API_KEY=...`

Or sync from secrets file:

```bash
grep CURSOR_API_KEY /etc/pmm-agentic-flow/env >> /opt/pmm-agentic-flow/src/.env
docker compose --env-file .env -f deploy/docker-compose.yml up -d --force-recreate agent-canvas
bash scripts/setup-cursor-acp.sh
```

### Browser login (no API key)

```bash
docker exec -it agent-canvas su -s /bin/bash openhands
export PATH="$HOME/.local/bin:$PATH"
NO_OPEN_BROWSER=1 agent login   # open URL on your laptop
agent status
```

Note: login tokens live in the container filesystem — lost on `recreate`. Prefer `CURSOR_API_KEY` for servers.

### Canvas UI

1. **Manage Backends** → add **Cursor** (ACP)
   - Command: `/home/openhands/.local/bin/agent`
   - Args: `acp`
2. **Settings** → default provider = that Cursor backend
3. New conversation → test message

Docs: [Cursor CLI ACP](https://cursor.com/docs/cli/acp)

## GitHub Copilot

Same pattern if your `copilot` build supports `acp`:

```bash
copilot login
copilot acp
```

Configure in Manage Backends: command + `acp` arg, stdio transport.

## Team note

For a shared VM, use a **service API key** in `/etc/pmm-agentic-flow/env`, not individual laptop logins.

## After container recreate

Re-run `bash scripts/setup-cursor-acp.sh` — the CLI is installed in the container image layer, not the Docker volume.
