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

## No custom domain (default)

Leave **`domain` empty** in `terraform.tfvars`. Terraform auto-computes:

```text
pmmagents.<linode-ip-with-dashes>.sslip.io
```

Example: IP `139.162.150.187` → **`https://pmmagents.139-162-150-187.sslip.io/`**

- No DNS registration, no two-step apply, no manual IP→hostname math
- Everyone uses the same **prefix** (`pmmagents`); only the IP segment changes per VM
- Override prefix: `domain_prefix = "pmmagents"` (default)
- Override full hostname: `domain = "loop.example.com"` (requires your own A record)

On the Linode, recover script and `scripts/loop-domain.sh` use the same formula.

**Note:** bare `pmmagents.sslip.io` (without the IP segment) does **not** resolve via sslip.io magic DNS — sslip.io needs the IP embedded in the hostname unless you own a real domain and add an A record.

## Example `terraform.tfvars` (fill yours — do not commit this file)

Copy from `terraform.tfvars.example`. **Never commit `terraform.tfvars`** (secrets).

```hcl
linode_token           = "PASTE from cloud.linode.com/profile/tokens"
root_password          = "Pick a strong password for ssh root@linode"
domain                 = ""   # empty = auto pmmagents.<ip-dashes>.sslip.io
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
