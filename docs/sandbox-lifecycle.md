# Sandbox lifecycle

## Control plane (host processes)

| Service | Port | URL |
|---------|------|-----|
| `agent-canvas` (systemd) | 8000 | **http://\<ip\>:8000/** |
| `orchestrator` (systemd) | 8080 | http://\<ip\>:8080/hooks/jira |

Agent Canvas and orchestrator run **on the VM** via npm + systemd ([OpenHands VM guide](https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm)).

**Docker** on the host is only for **per-chat sandboxes** — one container per conversation turn workspace.

No Caddy, no TLS, no cert warnings. POC only — add HTTPS when you have a domain.

## QA workers

| Component | Role |
|-----------|------|
| Worker VM | npm Agent Canvas + systemd (same as control plane) |
| PMM container | One `pmm-server` per worker (`:8443`), shared by chats on that VM |
| Chat sandboxes | Up to `chats_per_worker` tickets per worker; each QA chat = own Docker sandbox |

Orchestrator assigns workers from a pool (`config/stack.yaml` → `infrastructure.linode.chats_per_worker`). Empty workers are destroyed at Ready for Merge.

## Update Linode

```bash
cd /opt/pmm-agentic-flow/src && git pull
bash deploy/bootstrap-host.sh
```

**Cursor/Copilot** — `cursor_api_key` / `github_copilot_token` em `terraform.tfvars`. Ver [llm-acp.md](./llm-acp.md).

Firewall (Linode Cloud + ufw): **TCP 8000** and **8080**.

## Instance sizes

`config/stack.yaml` → `infrastructure.linode` (4GB control, 8GB QA worker, `chats_per_worker: 3`).

## Test without Jira

```bash
export ORCHESTRATOR_API_KEY=...
export ORCHESTRATOR_BASE_URL=http://<ip>:8080/orchestrator
./scripts/simulate-transition.sh PMM-15083 "In Progress"
```

## LLM — UI abre sem isso, mas chat precisa de backend

| O quê | UI abre? | Agente responde? |
|-------|----------|------------------|
| Só bootstrap-host | Sim | **Não** — falta provider |
| API key Anthropic/OpenAI no Canvas Settings | Sim | Sim |
| Cursor `agent acp` / Copilot `copilot acp` | Sim | Sim (via Manage Backends) |
| Cursor Cloud Agents API (`CURSOR_API_KEY`) | UI abre | **Não no chat** — agentes async em repo GitHub; ver [cursor-api.md](./cursor-api.md) |

**Cursor/Copilot no Terraform** — ver [llm-acp.md](./llm-acp.md).
