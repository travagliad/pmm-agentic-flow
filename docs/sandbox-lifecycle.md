# Sandbox lifecycle

## Architecture: central UI + remote sandboxes

Same pattern as OpenHands Cloud / Cursor Agents: **one Canvas UI** on the control plane; **per-ticket sandboxes** run agent-server only (no UI on the runner).

| Layer | Host | Role |
|-------|------|------|
| **Canvas UI** | Control plane `:8000` → ngrok | Single web app for all tickets |
| **Orchestrator** | Control plane `:8080` | Jira webhooks, Linode provisioning, agent triggers |
| **Sandbox proxy** | Orchestrator `/sandbox/{TICKET}/` → runner `:8000` | Same-origin API for browser backends |
| **Sandbox runner** | Ephemeral Linode per ticket | `agent-canvas --backend-only --public`, workspace `/projects/pmm` |

`config/stack.yaml` → `sandbox.mode: central_ui_remote_sandbox`

## Control plane URLs

| Service | Port | URL |
|---------|------|-----|
| Agent Canvas UI | 8000 | `https://<ngrok-domain>/` |
| Orchestrator | 8080 | `https://<ngrok-domain>/orchestrator/health` |
| Ticket chat bootstrap | 8080 | `https://<ngrok-domain>/tickets/PMM-12345/chat` |
| Sandbox API (proxied) | 8080 | `https://<ngrok-domain>/sandbox/PMM-12345/api/...` |

## Flow per ticket

1. **Ready for Refinement** — orchestrator provisions runner VM, waits for agent-server `:8000`.
2. Orchestrator creates conversation on **runner** via internal API (`http://<runner-ip>:8000`).
3. Jira comment posts `https://<ngrok>/tickets/PMM-12345/chat` (not runner IP).
4. User opens link → bootstrap registers sandbox as Canvas backend (`/sandbox/PMM-12345`) → opens conversation on main UI.
5. **In Progress / In QA** — same `conversationId`; orchestrator sends `/opsx:*` and `/loop:qa` to runner agent-server.
6. **Ready for Merge** — finalize prompts, destroy runner Linode.

ACP (Cursor `agent acp`) runs on the **control plane** only. Runners have no ACP CLI.

## Chat runners (backend-only)

| Component | Role |
|-----------|------|
| Runner VM | Dedicated Linode per Jira ticket |
| Agent Canvas | `backend-only --public` on `:8000` (agent-server + workspace) |
| Workspace | `/projects/pmm` + `/projects/pmm-qa` |
| Isolation | VM boundary — no Docker |

## Update control plane

```bash
cd /opt/pmm-agentic-flow/src && git pull
bash deploy/bootstrap-host.sh
```

## Instance sizes

| Role | Size | Config |
|------|------|--------|
| Control plane | `terraform.tfvars` → `instance_type` | UI + orchestrator |
| Sandbox runner | `config/stack.yaml` → `infrastructure.linode.runner_type` | one per ticket |

## Test without Jira

```bash
export JIRA_WEBHOOK_SECRET=...   # same as terraform api_secret
export ORCHESTRATOR_BASE_URL=http://<ip>:8080/orchestrator
./scripts/simulate-transition.sh PMM-15083 "In Progress"
```

Open the chat link from Jira comments or `https://<ngrok>/tickets/PMM-15083/chat`.

First visit to the main UI may prompt for `LOCAL_BACKEND_API_KEY` (same value as `agent_canvas_api_key` in tfvars).
