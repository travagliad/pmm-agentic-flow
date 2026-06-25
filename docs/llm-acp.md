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

### Install failures (HTTP 403)

`deploy/install-cursor-cli.sh` reads `DOWNLOAD_URL` from `https://cursor.com/install` (full lab version, e.g. `2026.06.24-00-45-58-9f61de7`). An older bug truncated the version hash (`2026.06.24-00-45-58`), which produced HTTP 403 — not Linode IP blocking.

If a specific lab version is unpublished on the CDN, Cursor may return 403 until they publish the artifact (see [Cursor forum](https://forum.cursor.com/t/cursor-cli-cannot-be-installed-installer-tried-to-download-asset-that-403s/155827)).

`deploy/install-cursor-cli.sh` retries 3×, validates the tarball, and fails bootstrap loudly on error.

**When `cursor_api_key` is set:** `deploy/seed-acp-backend.sh` registers `/usr/local/bin/agent acp` automatically after Canvas starts.

## Architecture: control plane vs runner chat

**Current POC behaviour:**

| Host | Agent Canvas role | Orchestrator uses it? |
|------|-------------------|----------------------|
| Control plane | UI via ngrok (`https://<domain>/`) for manual access | **No** — not where workflow messages go |
| Per-ticket runner VM | One Canvas per Jira ticket on `:8000` | **Yes** — `ensureRunner` + `dispatchCommand` in `orchestrator/src/workflow-engine.ts` |

When a ticket moves through the workflow, the orchestrator provisions a dedicated Linode runner and sends `/opsx:*` prompts to **that runner's** Canvas URL (`http://<runner-ip>:8000`), not the control plane chat.

**Target / future architecture:**

- **One** conversation on control plane Canvas per ticket.
- Runners act as **sandboxes only** (workspace isolation, no separate chat UI).
- Orchestrator would dispatch to control plane Canvas instead of per-runner Canvas.

That consolidation is not implemented yet; the runner-per-chat model is intentional for the current sandbox-isolation POC.

## Canvas UI

1. Control plane (manual): open `https://<ngrok-domain>/` or `http://<public_ip>:8000/`
2. Runner (per ticket): link posted in Jira comment by orchestrator
3. **Manage Backends** → Cursor: `/usr/local/bin/agent` + args `acp` (auto-seeded on bootstrap when `cursor_api_key` is set)
4. Or Copilot (only if Cursor not configured): `/usr/local/bin/copilot` + args `acp`

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
