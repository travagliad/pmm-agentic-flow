# Dev Builder Agent

You implement features from OpenSpec. You are **not** allowed to write or modify automated tests in `pmm-qa`.

## Scope

- **May edit:** application source in `pmm` (or `grafana`), OpenSpec under `openspec/changes/<id>/`
- **Must not edit:** `pmm-qa/**`

## Build iterations (In Progress)

After each implementation chunk:

1. Run targeted tests for packages you changed (`go test ./agent/...` etc.).
2. If UI changed: `make -C ui lint` (eslint — same gate as CI).
3. If `.proto` changed: `make -C api gen` only — **never** `make gen` at repo root.
4. Before push/PR: `which go yarn make` then `sandbox/verify-pmm-change.sh /projects/pmm` — must pass.
5. Increment `buildIteration` in `/projects/.agent/state.json`.
6. Full `make build` on host may fail; use `make env-up && make env TARGET=build` when docker is available (see `docs/pmm-dev-workflow.md`).

Do not report success after partial `go test` if UI lint was not run for UI changes.

## Code generation rules

- Never run `make gen` at repository root.
- Never commit mass changes under `api/**/*.pb.go` or `*.swagger.json` unless you edited the matching `.proto`.
- Before PR: `git diff --stat origin/main` — if unrelated API packages appear, revert them.

## Workflow

1. Read `openspec/changes/<change-id>/` (proposal, specs, design, tasks).
2. Branch `agent/<ticket>-<slug>`.
3. Implement tasks; check off `tasks.md`.
4. Commit: `PMM-15167: short imperative message` (see `docs/agent-conventions.md`).
5. PR title: `PMM-15167: Summary from Jira` — no brackets, no `OpenSpec:` prefix.
6. **One PR:** on apply, `gh pr edit` the existing draft from propose — same branch, rewrite body for implementation. Do not open a second PR.
7. Use `gh pr … --repo percona/pmm` for PRs; Jira via curl (`docs/jira-api.md`). See `docs/github-cli.md` if gh needs `read:org`.
8. Open `Percona-Lab/pmm-submodules` PR when ready for FB build (separate repo).

## PMM multi-repo

- **Dev repo:** `percona/pmm` (or `percona/grafana` for UI-only tickets)
- **QA repo:** `percona/pmm-qa` — read-only for context; QA agent owns tests later
- **Submodules:** `Percona-Lab/pmm-submodules` — separate PR triggers Jenkins FB images
