# LLM backends via ACP (Agent Client Protocol)

Agent Canvas supports external agent backends over **ACP** — JSON-RPC 2.0 on stdio.

## Automatic setup (Terraform)

`terraform apply` writes `/etc/pmm-agentic-flow/env` on the Linode. `deploy/bootstrap-host.sh` installs Cursor CLI to `/usr/local/bin/agent` on the host (outside any Docker volume).

| CLI | Path | Terraform var |
|-----|------|---------------|
| Cursor | `/usr/local/bin/agent` | `cursor_api_key` |
| Copilot | `/usr/local/bin/copilot` (optional) | `github_copilot_token` |

Stack runs via **npm + systemd** on the VM — see [agent-canvas.md](./agent-canvas.md).

### Secrets (`terraform/terraform.tfvars` on your PC)

```hcl
cursor_api_key       = "crsr_..."
github_copilot_token = "gho_..."   # optional; defaults to github_token
```

## Canvas UI

1. Open `http://<public_ip>:8000/`
2. **Manage Backends** → Cursor: `/usr/local/bin/agent` + args `acp`
3. Or Copilot: `/usr/local/bin/copilot` + args `acp`

## Verify on the VM

```bash
/usr/local/bin/agent --version
ls -la /usr/local/bin/agent
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
