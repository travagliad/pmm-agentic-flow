# GitHub CLI and token (control plane)

`GITHUB_TOKEN` in `terraform/terraform.tfvars` is written to `/etc/pmm-agentic-flow/env` and used by `gh auth login --with-token` for user `agentcanvas` during bootstrap.

## Classic PAT scopes (recommended)

Create at https://github.com/settings/tokens with:

| Scope | Why |
|-------|-----|
| `repo` | Push branches, open/edit PRs on `percona/pmm` |
| `read:org` | `gh pr edit`, org repo resolution — **without this, PR title/body updates fail** |
| `workflow` | Optional; only if triggering Actions |

After changing the token in tfvars:

```bash
cd /opt/pmm-agentic-flow/src && git pull
sudo bash deploy/bootstrap-host.sh   # re-auth gh for root + agentcanvas
```

Or only re-auth:

```bash
source /etc/pmm-agentic-flow/env
echo "$GITHUB_TOKEN" | gh auth login --with-token
sudo -u agentcanvas bash -lc 'set -a; source /etc/pmm-agentic-flow/agent-shell.env; set +a; echo "$GITHUB_TOKEN" | gh auth login --with-token'
```

`GITHUB_TOKEN` must also be exported for `agentcanvas` — bootstrap copies it to `/etc/pmm-agentic-flow/jira.env` is Jira-only. Add to install script or use full env via systemd (agent-canvas service already has `EnvironmentFile`).

## Fine-grained PAT alternative

Repository access: `percona/pmm` — Contents Read/Write, Pull requests Read/Write. No `read:org` needed if every `gh` command uses `--repo percona/pmm`.

```bash
gh pr edit 5549 --repo percona/pmm --title "PMM-15167: Real-Time Query Analytics for PostgreSQL"
```

## Manual PR title when gh fails

Edit on GitHub UI — agent cannot fix title without token scopes.
