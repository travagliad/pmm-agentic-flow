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

## One PR per ticket (propose → apply)

| Phase | PR |
|-------|-----|
| Propose | Open **one** draft PR on `agent/<ticket>-<slug>`. Body: `## Summary` (feature), `## OpenSpec (draft)`, `## Test plan` (spec review checkboxes). |
| Apply | **Same PR** — push implementation commits, `gh pr edit` to replace body with implementation summary + changes + test plan. Remove spec-only wording. |
| Ready | `gh pr ready` after `make -C ui lint` / verify script passes. |

Forbidden: title/body starting with "OpenSpec proposal for…"; footer "Made with Cursor"; opening a second PR on apply.

## Agent state file

`/projects/.agent/state.json` — ticket phase, `buildIteration`, PR URLs.

## Jira context

**No Atlassian Rovo MCP** (not authorized). Use curl with `JIRA_EMAIL`, `JIRA_API_TOKEN`, `JIRA_BASE_URL` from the shell environment (`docs/jira-api.md`).

## PMM codegen and lint

See `docs/pmm-dev-workflow.md`. Summary:

- Before PR: `sandbox/verify-pmm-change.sh /projects/pmm`
- UI: `make -C ui lint`
- Never `make gen` at repo root; never mass-commit unrelated `api/*.pb.go`
