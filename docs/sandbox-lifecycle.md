# Sandbox lifecycle

## Control plane (orchestrator + Canvas UI)

| Service | Port | URL |
|---------|------|-----|
| `agent-canvas` (systemd) | 8000 | `https://<ngrok-domain>/` or `http://<ip>:8000/` |
| `orchestrator` (systemd) | 8080 | http://\<ip\>:8080/hooks/jira |
| nginx + ngrok (optional) | 8787 → HTTPS | stable webhook + Canvas ingress |

The control plane runs **orchestrator + Agent Canvas** (Node + npm + systemd). No Docker on the host.

Workflow prompts (`/opsx:*`, `/loop:qa`) still go to the **per-ticket runner** Canvas today — control plane Canvas is for manual UI access via ngrok. See [llm-acp.md](./llm-acp.md#architecture-control-plane-vs-runner-chat) and [architecture-target.md](./architecture-target.md).

## Chat runners (one Linode per ticket)

| Component | Role |
|-----------|------|
| Runner VM | Dedicated Linode per Jira ticket |
| Agent Canvas | npm + systemd on the VM (`:8000`) |
| Workspace | `/projects/pmm` + `/projects/pmm-qa` cloned on the VM |
| Isolation | **VM boundary** — no Docker sandboxes |

Orchestrator provisions a runner on **Ready for Refinement** (first agent phase). Dev and QA share the **same conversation** on that runner. Runner is destroyed at **Ready for Merge**.

Canvas URL is posted in Jira comments (`http://<runner-ip>:8000`).

## Update control plane

```bash
cd /opt/pmm-agentic-flow/src && git pull
bash deploy/bootstrap-host.sh
```

**Cursor/Copilot** — `cursor_api_key` / `github_copilot_token` in `terraform.tfvars`. See [llm-acp.md](./llm-acp.md).

Firewall (control plane): **TCP 8080** (or ngrok only — ports closed).

## Instance sizes

| Role | Size | Config |
|------|------|--------|
| Control plane | `terraform.tfvars` → `instance_type` | orchestrator only |
| Chat runner | `config/stack.yaml` → `infrastructure.linode.runner_type` | one per ticket |

## Test without Jira

```bash
export JIRA_WEBHOOK_SECRET=...   # same as terraform api_secret
export ORCHESTRATOR_BASE_URL=http://<ip>:8080/orchestrator
./scripts/simulate-transition.sh PMM-15083 "In Progress"
```

## LLM — UI opens only after runner is ready

| What | When |
|------|------|
| Runner provisioning | ~5–10 min after first agent phase |
| Canvas UI | `http://<runner-ip>:8000` (link in Jira) |
| Cursor `agent acp` / Copilot `copilot acp` | Installed on runner via cloud-init |

See [llm-acp.md](./llm-acp.md).
