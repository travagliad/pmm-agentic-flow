# Deploying on Linode

Terraform **creates the server**. Docker Compose **runs on that server**. You do not run the stack on your laptop for production.

```text
Your laptop                         Linode VM (Ubuntu 24.04)
─────────────                       ─────────────────────────
terraform apply  ───────────────►    cloud-init:
                                     1. install Docker
                                     2. git clone this repo
                                     3. write /etc/pmm-agentic-flow/env
                                     4. docker compose up -d --build
                                           ├── Caddy (TLS :443)
                                           ├── OpenHands
                                           ├── LiteLLM
                                           └── Orchestrator
```

Local `docker compose` is **optional** — only for developing the orchestrator or testing compose changes before pushing to GitHub.

---

## Prerequisites

1. **Push this repo to GitHub** (cloud-init clones it on first boot).
2. **Linode API token** with Linode read/write + Firewall.
3. **DNS** — a domain or subdomain you control (e.g. `loop.example.com`).
4. Secrets ready (see `terraform/terraform.tfvars.example`).

---

## Step 1 — Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set bootstrap_repo_url to YOUR GitHub repo URL
```

Important variables:

| Variable | Purpose |
|----------|---------|
| `bootstrap_repo_url` | Git URL cloud-init clones onto the Linode |
| `domain` | Hostname for Caddy + TLS |
| `github_copilot_token` | LiteLLM → Copilot |
| `admin_cidrs` | Lock SSH to your IP |

---

## Step 2 — Apply

```bash
terraform init
terraform plan
terraform apply
```

Note outputs:

```bash
terraform output public_ip
terraform output dns_hint
terraform output next_steps
```

---

## Step 3 — DNS

Create an **A record**:

```text
loop.example.com  →  <public_ip from terraform output>
```

Wait for propagation (minutes to hours).

---

## Step 4 — Verify on the Linode

SSH in (password from `root_password` in tfvars, or add your SSH key via Linode console):

```bash
ssh root@<public_ip>

# cloud-init progress
tail -f /var/log/pmm-agentic-flow-bootstrap.log

# stack health
docker ps
curl -s localhost:8080/health
```

When DNS and Let's Encrypt are ready:

```text
https://loop.example.com/          → OpenHands UI
https://loop.example.com/hooks/jira → Jira webhook
```

---

## Step 5 — Run a ticket (from your laptop)

Point scripts at the **Linode URL**, not localhost:

```bash
export LOOP_BASE_URL=https://loop.example.com
export ORCHESTRATOR_API_KEY=<same as terraform orchestrator_api_key>

./scripts/simulate-transition.sh PMM-14915 "Ready for Refinement" "Feature summary"
./scripts/simulate-transition.sh PMM-14915 "In Progress"
```

---

## Updates after code changes

Push to GitHub, then on the Linode:

```bash
ssh root@<public_ip>
cd /opt/pmm-agentic-flow/src
git pull
cd deploy
docker compose --env-file ../.env up -d --build
```

Or re-run `terraform apply` only if you changed cloud-init / instance size — not for app code changes.

---

## Local dev (optional)

Only if you want to hack on the orchestrator without a Linode:

```bash
cp .env.example .env
# set LOOP_DOMAIN=localhost and skip TLS, or use ngrok
./scripts/deploy-stack.sh
```

This does **not** replace the Linode deployment for PMM sandboxes — nested Docker sandboxes need a Linux host with Docker socket access; the Linode VM is that host.
