# LLM backends via ACP (Agent Client Protocol)

Agent Canvas supports external agent backends over **ACP** — JSON-RPC 2.0 on stdio.

## Automatic setup (Terraform)

`terraform apply` writes `/etc/pmm-agentic-flow/env` on the Linode. `deploy/bootstrap-host.sh` runs `deploy/install-acp-clis.sh`, which installs ACP CLIs to `/usr/local/bin` on the host (outside any Docker volume).

| CLI | Path | Terraform var |
|-----|------|---------------|
| Cursor | `/usr/local/bin/agent` | `cursor_api_key` |
| Copilot | `/usr/local/bin/copilot` | `github_copilot_token` (falls back to `github_token`) |

Stack runs via **npm + systemd** on the VM — see [agent-canvas.md](./agent-canvas.md).

### Secrets (`terraform/terraform.tfvars` on your PC)

```hcl
cursor_api_key       = "crsr_..."
github_copilot_token = "gho_..."   # optional; defaults to github_token
```

`deploy/install-acp-clis.sh` always attempts Cursor CLI install. When `cursor_api_key` is set in tfvars, bootstrap **requires** `/usr/local/bin/agent` — Copilot does not satisfy that requirement. Copilot is optional only when Cursor is not configured.

`deploy/install-cursor-cli.sh` runs the **official** installer as user `agentcanvas` (the same user as the Canvas systemd service), then symlinks `agent` to `/usr/local/bin/agent`.

Bootstrap **fails** if `cursor_api_key` is set and `agent --version` does not work.

## Canvas UI (manual)

1. Open `https://<ngrok-domain>/` or `http://<public_ip>:8000/`
2. **Manage Backends** → command `agent`, args `acp` ([Cursor CLI](https://cursor.com/docs/cli/installation))

## Architecture: central UI + sandbox runners

| Host | Role | Orchestrator |
|------|------|--------------|
| Control plane | **Main Canvas UI** (`https://<domain>/`) + ACP (`agent acp`) | Jira webhooks, Linode provisioning |
| Per-ticket sandbox VM | `agent-canvas --backend-only --public` — agent-server + `/projects/pmm` | **Triggers** `/opsx:*` and `/loop:qa` via runner IP (internal) |

Users open **one URL** per ticket: `https://<ngrok>/tickets/PMM-12345/chat`. Bootstrap registers the sandbox as a Canvas backend at `/sandbox/PMM-12345/` (same-origin proxy) and opens the conversation on the main UI.

ACP runs on the **control plane only** — not on sandbox runners.

See [sandbox-lifecycle.md](./sandbox-lifecycle.md) and [architecture-target.md](./architecture-target.md).

## Verify on the VM

```bash
/usr/local/bin/agent --version    # or:
/usr/local/bin/copilot --version
ls -la /usr/local/bin/agent /usr/local/bin/copilot
```

## Re-deploy after secret changes

```powershell
cd terraform && terraform apply
```

On existing VM (cloud-init runs only on first boot):

```bash
cd /opt/pmm-agentic-flow/src && git pull
bash deploy/bootstrap-host.sh
systemctl restart agent-canvas
```
