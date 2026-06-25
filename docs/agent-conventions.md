# Agent conventions (branches, PRs, titles)

## Git branch

```
agent/<TICKET>-<slug>
```

Example: `agent/PMM-15167-rta-real-time-query-analytics-for-postgr`

Never use a `loop/` prefix.

## PR and commit titles

Format:

```
PMM-15167: Real-Time Query Analytics for PostgreSQL
```

Rules:

- Ticket key, colon, space, human-readable summary from Jira
- No square brackets around the ticket
- No `OpenSpec:` prefix in the PR title (OpenSpec lives under `openspec/changes/` in the branch — that is enough)
- Commits use the same prefix: `PMM-15167: <short imperative>`

## Agent state file

`/projects/.agent/state.json` — ticket phase, `buildIteration`, PR URLs.

## Jira context

**No Atlassian Rovo MCP** (not authorized). Use REST API with credentials on the host (`docs/jira-api.md`):

```bash
bash scripts/jira-issue.sh PMM-15167
```

Orchestrator injects summary/description on webhook transitions; call the API when you need fresh fields mid-chat.

## PMM codegen and lint

See `docs/pmm-dev-workflow.md`. Summary:

- Before PR: `sandbox/verify-pmm-change.sh /projects/pmm`
- UI: `make -C ui lint`
- Never `make gen` at repo root; never mass-commit unrelated `api/*.pb.go`
