# Getting started — test on Linode (not your PC)

> **Do not run** `docker compose` on your laptop for this project.  
> That installs OpenHands + nested sandboxes **locally** and is not the intended setup.

---

## If you already ran it locally by mistake

**Windows (PowerShell):**

```powershell
cd C:\Users\davi_\vscodeProjects\pmm-agentic-flow\deploy
docker compose --env-file ..\.env down -v --remove-orphans
```

**Or:**

```bash
./scripts/teardown-local.sh
```

Verify nothing `loop-*` is left:

```powershell
docker ps -a
```

Your old `pmm-server` container (if any) is unrelated — remove separately only if you do not need it:

```powershell
docker rm pmm-server   # optional
```

---

## Checklist — ready to test (Linode)

### A. One-time prep (your PC)

- [ ] **GitHub:** push `pmm-agentic-flow` to a repo you control  
  Example: `https://github.com/travagliad/pmm-agentic-flow.git`
- [ ] **Linode:** account + [API token](https://cloud.linode.com/profile/tokens) (read/write Linodes + Firewalls)
- [ ] **Domain:** subdomain for the loop, e.g. `loop.yourdomain.com` (DNS access)
- [ ] **Secrets:** GitHub PAT (`repo`), Copilot/LiteLLM token, random keys for `litellm_master_key`, `openhands_api_key`, `orchestrator_api_key`
- [ ] **Terraform** installed on PC: [terraform.io/downloads](https://developer.hashicorp.com/terraform/install)

### B. Deploy the server (your PC → creates Linode)

```powershell
cd C:\Users\davi_\vscodeProjects\pmm-agentic-flow\terraform
copy terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars   # fill ALL values — especially bootstrap_repo_url
```

Required in `terraform.tfvars`:

| Variable | Example |
|----------|---------|
| `linode_token` | Linode API token |
| `root_password` | Strong password for SSH |
| `domain` | `loop.yourdomain.com` |
| `bootstrap_repo_url` | Your GitHub repo URL |
| `github_token` | `ghp_...` |
| `github_copilot_token` | Copilot / `gh auth token` |
| `admin_cidrs` | See [Why your IP?](#why-admin_cidrs-your-public-ip) below |

#### Why `admin_cidrs` (your public IP)?

This is **not** for running the stack on your PC. Everything (OpenHands, agents, sandboxes) runs on the **Linode**.

`admin_cidrs` only controls **who may SSH into the Linode** (port 22) via the Linode firewall Terraform creates:

| Value | Meaning |
|-------|---------|
| `["YOUR.PUBLIC.IP/32"]` | Only you can SSH to the server (recommended) |
| `["0.0.0.0/0"]` | Anyone on the internet can try SSH (OK for quick POC, weaker) |

Your **public** IP is what websites see when you browse — not `192.168.x.x`. Check: [https://ifconfig.me](https://ifconfig.me)

HTTPS (OpenHands UI, Jira webhooks) stays open to everyone on `:443` — that is separate from SSH.

```powershell
terraform init
terraform apply
```

Save outputs:

```powershell
terraform output public_ip
terraform output next_steps
```

### C. DNS (browser access)

At your DNS provider:

```text
loop.yourdomain.com   A   <public_ip>
```

Wait 5–15 minutes for propagation.

### D. Verify on Linode (~5 min after apply)

```powershell
ssh root@<public_ip>
# password = root_password from tfvars

tail -f /var/log/pmm-agentic-flow-bootstrap.log
docker ps
curl -s localhost:8080/health
```

When DNS + TLS are ready, open in browser:

```text
https://loop.yourdomain.com/
```

### E. Trigger a test ticket (from your PC — PC can go offline after)

```powershell
$env:LOOP_BASE_URL = "https://loop.yourdomain.com"
$env:ORCHESTRATOR_API_KEY = "<orchestrator_api_key from terraform.tfvars>"

bash ./scripts/simulate-transition.sh PMM-14915 "Ready for Refinement" "Test feature"
```

Or open OpenHands in the browser and type:

```text
/opsx:propose PMM-14915
```

---

## What runs where

| Component | Runs on |
|-----------|---------|
| OpenHands, LiteLLM, Orchestrator, Caddy | **Linode 24/7** |
| PMM sandboxes (per ticket) | **Linode** (nested Docker on the VM) |
| Terraform apply | Your PC (minutes, once) |
| Browser / Jira webhook | Any device; PC **not** required to stay on |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| cloud-init failed | `ssh root@IP` → `cat /var/log/pmm-agentic-flow-bootstrap.log` |
| clone failed | `bootstrap_repo_url` must be a **public** repo or use token in URL |
| TLS not working | DNS not pointing to Linode yet; wait or check A record |
| litellm unhealthy | Check `GITHUB_COPILOT_TOKEN` in `/opt/pmm-agentic-flow/src/.env` on Linode |

See also: [deploy-linode.md](./deploy-linode.md)
