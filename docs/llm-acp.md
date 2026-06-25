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

`deploy/install-acp-clis.sh` always attempts Cursor CLI install. Copilot is installed when `GITHUB_COPILOT_TOKEN` or `GITHUB_TOKEN` is set. Bootstrap **fails** if `CURSOR_API_KEY` is set but neither CLI is available.

### Install failures (Cursor CDN 403)

Cursor CLI is downloaded from `downloads.cursor.com`. Some cloud provider IPs (including Linode) may receive **HTTP 403** from that CDN. Previously, `install-agent-canvas.sh` swallowed this error (`|| true`), so Agent Canvas started without `/usr/local/bin/agent`.

**Mitigation:**

1. Set `github_copilot_token` (or rely on `github_token`) in `terraform.tfvars` so bootstrap installs Copilot ACP as fallback.
2. `deploy/seed-acp-backend.sh` (called from `bootstrap-host.sh` after Agent Canvas starts) auto-registers Copilot via `PATCH /api/settings` when `/usr/local/bin/agent` is missing.
3. Settings persist in `/home/agentcanvas/.openhands/settings.json` (also reachable at `GET/PATCH /api/settings` with `X-Session-API-Key`).
4. Re-run bootstrap after fixing secrets — failures are no longer ignored.

`deploy/install-cursor-cli.sh` retries downloads 3×, validates the tarball before extract, and prints explicit messages on HTTP 403.

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
3. **Manage Backends** → Cursor: `/usr/local/bin/agent` + args `acp`
4. Or Copilot: `/usr/local/bin/copilot` + args `acp`

Bootstrap auto-seeds step 4 when Cursor CLI is unavailable (see `deploy/seed-acp-backend.sh`).

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
