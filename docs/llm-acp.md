# LLM backends via ACP (Agent Client Protocol)

Agent Canvas supports external agent backends over **ACP** — JSON-RPC 2.0 on stdio.

## Automatic setup (Terraform)

`terraform apply` writes `/etc/pmm-agentic-flow/env` on the Linode. Cloud-init runs docker compose with that file. On every `agent-canvas` start, `deploy/agent-canvas-entrypoint.sh` **always** installs missing CLIs:

| CLI | Path | Terraform var |
|-----|------|---------------|
| Cursor | `/usr/local/bin/agent` | `cursor_api_key` |
| Copilot | `/usr/local/bin/copilot` (symlink) | `github_copilot_token` |

Cursor installs to `/usr/local/bin` (not under the `agent-canvas-local` volume — that mount hides `~/.local` from the image).

### Secrets (`terraform/terraform.tfvars` on your PC)

```hcl
cursor_api_key       = "crsr_..."
github_copilot_token = "gho_..."   # optional; defaults to github_token
```

## Canvas UI

1. Open `http://<public_ip>:8000/`
2. **Manage Backends** → Cursor: `/usr/local/bin/agent` + args `acp` (or command `agent` if PATH is set)
3. Or Copilot: `/usr/local/bin/copilot` + args `acp`

## Verify on the VM

```bash
docker exec agent-canvas ls -la /usr/local/bin/agent /usr/local/bin/copilot
```

## Re-deploy after secret changes

```powershell
cd terraform && terraform apply
```

On existing VM (cloud-init runs only on first boot):

```bash
cd /opt/pmm-agentic-flow/src/deploy
docker compose --env-file /etc/pmm-agentic-flow/env up -d --force-recreate agent-canvas
```
