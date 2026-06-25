# Terraform variables review

Single source on your PC: `terraform/terraform.tfvars` → cloud-init writes `/etc/pmm-agentic-flow/env` on the VM.

Worker Linode size/region: **`config/stack.yaml`** only (not terraform).

---

## Required (POC)

| Terraform var | VM env | Who uses it | Why |
|---------------|--------|-------------|-----|
| `linode_token` | `LINODE_TOKEN` | Orchestrator | Create/destroy QA worker Linodes |
| `root_password` | — | You (SSH) | Root login to control plane |
| `worker_root_password` | — | Linode API | Root on QA worker VMs |
| `bootstrap_repo_url` | `BOOTSTRAP_REPO_URL` | cloud-init | Clone this repo |
| `github_token` | `GITHUB_TOKEN` | Orchestrator + agents | Clone, PRs, FB resolver |
| `agent_canvas_api_key` | `LOCAL_BACKEND_API_KEY`, `AGENT_CANVAS_API_KEY` | Browser + orchestrator | Canvas `--public` gate; orchestrator calls Canvas API |
| `agent_canvas_secret_key` | `OH_SECRET_KEY` | Agent Canvas | Encrypt settings/secrets on disk |
| `api_secret` | `ORCHESTRATOR_API_KEY`, `JIRA_WEBHOOK_SECRET` | Scripts + Jira + you | **`/orchestrator/*`** needs `x-api-key`; **`/hooks/jira`** needs `x-webhook-secret` — same secret, two headers |

## Optional

| Terraform var | VM env | Default | Purpose |
|---------------|--------|---------|---------|
| `github_copilot_token` | `GITHUB_COPILOT_TOKEN` | `github_token` | Copilot ACP CLI |
| `cursor_api_key` | `CURSOR_API_KEY` | empty | Cursor ACP CLI |
| `agent_canvas_version` | `AGENT_CANVAS_VERSION` | `latest` | npm `@openhands/agent-canvas` pin |
| `jira_base_url` | `JIRA_BASE_URL` | empty | Jira comments (needs email + token too) |
| `jira_email` | `JIRA_EMAIL` | empty | Jira REST auth |
| `jira_api_token` | `JIRA_API_TOKEN` | empty | Jira REST auth |
| `ngrok_authtoken` | `NGROK_AUTHTOKEN` | empty | ngrok tunnel (recommended prod) |
| `ngrok_domain` | `NGROK_DOMAIN` | empty | Static HTTPS URL |
| `expose_ports_directly` | `EXPOSE_PORTS_DIRECTLY` | `false` | Open :8000/:8080 on firewall (dev) |
| `data_volume_size` | — | `50` | GB block volume; `0` = off |

## Infrastructure (not secrets)

| Terraform var | Default | Purpose |
|---------------|---------|---------|
| `label` | `agentic-flow` | Linode + firewall label |
| `region` | `eu-central` | Control plane region |
| `instance_type` | `g6-standard-4` | Control plane RAM/CPU |
| `admin_cidrs` | `["0.0.0.0/0"]` | Who can SSH :22 — **set your IP** |
| `admin_cidrs_v6` | `["::/0"]` | SSH over IPv6 |
| `tags` | `[]` | Linode tags |

## Removed (greenfield)

| Was | Why removed |
|-----|-------------|
| `orchestrator_api_key` | Merged into **`api_secret`** |
| `jira_webhook_secret` | Merged into **`api_secret`** |
| `openhands_api_key` | Duplicate of `agent_canvas_api_key` |
| `openhands_version` | Unused |
| `worker_linode_type` / `worker_linode_region` | Duplicated `config/stack.yaml` |

## Keys you generate (PowerShell)

```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

Run **twice**: `agent_canvas_api_key`, `agent_canvas_secret_key`, `api_secret` — or three times if you want distinct values (only `api_secret` is required for loop API + Jira).

## Why `api_secret` exists (not redundant with Canvas key)

| Endpoint | Header | Secret |
|----------|--------|--------|
| Agent Canvas `:8000` | Bearer / UI prompt | `agent_canvas_api_key` |
| `POST /orchestrator/tickets/transition` | `x-api-key` | `api_secret` |
| `POST /hooks/jira` | `x-webhook-secret` | `api_secret` |

OpenHands does **not** replace this — it has no Jira webhook or PMM workflow API.

## Set only on VM (not terraform)

Written by cloud-init from public IP or ngrok:

- `AGENT_CANVAS_PUBLIC_URL`
- `AGENT_CANVAS_BASE_URL` (= `http://127.0.0.1:8000`)
- `STACK_CONFIG_PATH`, `JIRA_WORKFLOW_PATH`, `DATA_DIR`
