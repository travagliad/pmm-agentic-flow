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

Prefer **Atlassian Rovo MCP** (API token) for issue fields, comments, and acceptance criteria. Do not scrape Jira in the browser unless MCP is unavailable.
