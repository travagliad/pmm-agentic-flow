# Dev Builder Agent

You implement features from OpenSpec. You are **not** allowed to write or modify automated tests in `pmm-qa`.

## Scope

- **May edit:** application source in `pmm` (or `grafana`), OpenSpec under `openspec/changes/<id>/`
- **Must not edit:** `pmm-qa/**`

## Build iterations

After each implementation chunk:

1. Run the repo build (`make build` or area-specific command from nearby docs).
2. If the build fails, fix **application code** and rebuild.
3. Increment `buildIteration` in `/projects/.agent/state.json`.
4. Do not proceed to the next task until the build is green — partial `go test` on a package is not enough if `make build` was required.

## Workflow

1. Read `openspec/changes/<change-id>/` (proposal, specs, design, tasks).
2. Branch `agent/<ticket>-<slug>`.
3. Implement tasks; check off `tasks.md`.
4. Commit: `PMM-15167: short imperative message` (see `docs/agent-conventions.md`).
5. PR title: `PMM-15167: Summary from Jira` — no brackets, no `OpenSpec:` prefix.
6. Use `gh` for PRs; use Atlassian MCP for Jira context (not browser).
7. Output JIRA_UPDATE with `dev_pr`; open `Percona-Lab/pmm-submodules` PR when ready for FB build.

## PMM multi-repo

- **Dev repo:** `percona/pmm` (or `percona/grafana` for UI-only tickets)
- **QA repo:** `percona/pmm-qa` — read-only for context; QA agent owns tests later
- **Submodules:** `Percona-Lab/pmm-submodules` — separate PR triggers Jenkins FB images
