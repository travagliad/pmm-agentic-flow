# Deploying on Linode

`terraform apply` provisions the full stack. No manual steps on the VM.

```text
terraform apply
  → cloud-init: git clone + bootstrap-host.sh
  → npm install -g @openhands/agent-canvas  (official VM install)
  → systemd: agent-canvas + orchestrator
  → optional: ngrok → stable HTTPS domain
  → optional: block volume → chats survive Linode migration
```

See [architecture-faq.md](./architecture-faq.md) for systemd vs OpenHands tmux, why Docker stays on the host, orchestrator scope, and what users need.

## Public URL (recommended)

In `terraform.tfvars`:

```hcl
ngrok_authtoken = "..."                        # ngrok dashboard
ngrok_domain    = "https://your-app.ngrok-free.app"
admin_cidrs     = ["YOUR.PUBLIC.IP/32"]        # SSH only
```

Outputs after apply:

- `app_url` — Canvas for users
- `jira_webhook_url` — `https://<domain>/hooks/jira`
- `data_volume_id` — detach/reattach when replacing Linode

## Dev fallback (no ngrok)

```hcl
expose_ports_directly = true
```

Opens :8000 and :8080 on the Linode firewall. Not recommended for production.

## Apply

```powershell
cd terraform
copy terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Wait ~8 minutes. Use `terraform output next_steps`.
