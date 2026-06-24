# Tokens, secrets, and filling `terraform.tfvars`

No custom domain? See [No domain (sslip.io)](#no-custom-domain) below.

---

## Links to generate tokens

| What | Where | Notes |
|------|-------|-------|
| **Linode API token** | https://cloud.linode.com/profile/tokens | Create token → Read/Write for Linodes + Firewalls |
| **GitHub PAT** (clone private repos, PRs) | https://github.com/settings/tokens | Classic token → scopes: `repo` |
| **GitHub CLI login** (optional, for `gh auth token`) | https://cli.github.com/ | Run `gh auth login` in terminal |
| **Copilot / LLM token** | Use output of `gh auth token` after login, or a PAT with Copilot access | Goes in `github_copilot_token` |
| **Jira API token** (optional for now) | https://id.atlassian.com/manage-profile/security/api-tokens | Only if posting comments to Jira |
| **Your public IP** (SSH firewall only) | https://ifconfig.me or https://ifconfig.io | IPv4 → `/32`; IPv6 → `/128`. POC: use `0.0.0.0/0` and `::/0` |

Generate random strings locally (PowerShell):

```powershell
# orchestrator_api_key, openhands_api_key, litellm_master_key, jira_webhook_secret
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

Run three times for three different keys.

---

## No custom domain

Use **sslip.io** — free DNS that points a hostname to your Linode IP. No registration.

Format: if Linode IP is `203.0.113.50`, hostname is:

```text
203-0-113-50.sslip.io
```

(dots → dashes, then `.sslip.io`)

### Two-step Terraform (no domain purchase)

**Step 1 — create the Linode** (temporary domain placeholder):

In `terraform.tfvars` use any placeholder for first apply:

```hcl
domain = "bootstrap.sslip.io"
```

Run:

```powershell
cd terraform
terraform init
terraform apply
```

Note the IP:

```powershell
terraform output public_ip
```

**Step 2 — set real sslip.io hostname and re-apply:**

If IP is `203.0.113.50`:

```hcl
domain = "203-0-113-50.sslip.io"
```

```powershell
terraform apply
```

Wait ~5 minutes for cloud-init / Caddy to pick up TLS.

Open in browser:

```text
https://203-0-113-50.sslip.io/
```

---

## Example `terraform.tfvars` (fill yours — do not commit this file)

Copy from `terraform.tfvars.example`. **Never commit `terraform.tfvars`** (secrets).

```hcl
linode_token           = "PASTE from cloud.linode.com/profile/tokens"
root_password          = "Pick a strong password for ssh root@linode"
domain                 = "203-0-113-50.sslip.io"   # after step 2 above
acme_email             = "your.email@example.com"    # any real email (Let's Encrypt)
bootstrap_repo_url     = "https://github.com/travagliad/pmm-agentic-flow.git"

github_token           = "ghp_..."                    # github.com/settings/tokens
github_copilot_token   = "gho_..."                    # gh auth token

litellm_master_key     = "random-string-1"
litellm_model          = "github/gpt-4.1"
openhands_api_key      = "random-string-2"
orchestrator_api_key   = "random-string-3"

region                 = "eu-central"
instance_type          = "g6-dedicated-8"
admin_cidrs            = ["0.0.0.0/0"]               # POC: open SSH; tighten later to YOUR.IP/32

# Optional — leave empty until Jira is wired
jira_base_url          = ""
jira_email             = ""
jira_api_token         = ""
jira_webhook_secret    = "random-string-4"
```

---

## What each field is for

| Field | Runs on | Purpose |
|-------|---------|---------|
| `linode_token` | Your PC → Linode API | Creates the VM |
| `root_password` | Linode | SSH login as root |
| `domain` | Linode (Caddy TLS) | URL you open in browser |
| `acme_email` | Let's Encrypt | TLS certificate notifications |
| `bootstrap_repo_url` | Linode cloud-init | Clones this GitHub repo on the server |
| `github_token` | Linode (agents) | Clone PMM, open PRs |
| `github_copilot_token` | Linode (LiteLLM) | LLM for OpenHands |
| `litellm_master_key` | Linode internal | LiteLLM ↔ OpenHands auth |
| `openhands_api_key` | Linode internal | Orchestrator ↔ OpenHands |
| `orchestrator_api_key` | You → Linode API | Your scripts calling `/api/tickets` |
| `admin_cidrs` | Linode firewall | **Who can SSH** — not where the app runs |

---

## After apply

```powershell
ssh root@<public_ip>
tail -f /var/log/pmm-agentic-flow-bootstrap.log
docker ps
```

Browser: `https://<your-sslip-hostname>/`

Test ticket:

```powershell
$env:LOOP_BASE_URL = "https://203-0-113-50.sslip.io"
$env:ORCHESTRATOR_API_KEY = "<same as orchestrator_api_key in tfvars>"
bash ./scripts/simulate-transition.sh PMM-14915 "Ready for Refinement" "Test"
```
