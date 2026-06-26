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

## Functional smoke test (mandatory before In Review)

After build/lint pass and **before** FB submodules PR or reporting dev complete:

1. Read `docs/dev-smoke-test.md` and `pmm-qa/qa-integration/pmm_qa/scripts/database_options.py`.
2. Provision databases matching the ticket (PostgreSQL, MySQL, MongoDB, etc. — not only PG).
3. Run smoke tests that prove the feature works (agent add, API, UI spot-check).
4. **Teardown** — `sandbox/dev-smoke-test.sh --destroy` or `pmm-framework.py --destroy`.

```bash
# Example: PostgreSQL RTA ticket
bash /opt/pmm-agentic-flow/src/sandbox/dev-smoke-test.sh --database ps=17
# … smoke tests …
bash /opt/pmm-agentic-flow/src/sandbox/dev-smoke-test.sh --destroy
```

**Forbidden:** skipping with "Managed DB tests — skip (no PostgreSQL test instance on control plane)". Docker is on the control plane — create what you need, then destroy it.

Record smoke steps and results in the PR Test plan.

## Code generation rules

- Never run `make gen` at repository root.
- Never commit mass changes under `api/**/*.pb.go` or `*.swagger.json` unless you edited the matching `.proto`.
- Before PR: `git diff --stat origin/main` — if unrelated API packages appear, revert them.

## Workflow

1. Read `openspec/changes/<change-id>/` (proposal, specs, design, tasks).
2. Branch `PMM-XXXX` (ticket key only — no `/`, required for pmm-submodules FB).
3. Implement tasks; check off `tasks.md`.
4. Commit: `PMM-15167: short imperative message` (see `docs/agent-conventions.md`).
5. PR title: `PMM-15167: Summary from Jira` — no brackets, no `OpenSpec:` prefix.
6. **One PR:** on apply, `gh pr edit` the existing draft from propose — same branch, rewrite body for implementation. Do not open a second PR.
7. Use `gh pr … --repo percona/pmm` for PRs; Jira via curl (`docs/jira-api.md`). See `docs/github-cli.md` if gh needs `read:org`.

## Dev complete — FB build (mandatory last step)

**Only after** smoke test passes, `verify-pmm-change.sh` passes, and the percona/pmm PR is ready (`gh pr ready`):

1. Clone/update `Percona-Lab/pmm-submodules` (separate repo).
2. Point the **pmm** submodule at branch `PMM-XXXX` (same name as percona/pmm feature branch).
3. Open a PR on `Percona-Lab/pmm-submodules` — title **must** include the ticket key (e.g. `PMM-15167: …`).
4. Jenkins (`JNKPercona`) comments `Server docker:` / `Client docker:` on that PR — required before In QA.
5. Post the submodules PR URL in chat. **Do not** report dev complete without this PR.

```bash
gh pr create --repo Percona-Lab/pmm-submodules \
  --title "PMM-15167: Real-Time Query Analytics for PostgreSQL" \
  --body "FB build; pmm branch PMM-15167"
```

Skipping this blocks In QA (orchestrator cannot resolve FB images).

## PMM multi-repo

- **Dev repo:** `percona/pmm` (or `percona/grafana` for UI-only tickets)
- **QA repo:** `percona/pmm-qa` — read-only for context; QA agent owns tests later
- **Submodules:** `Percona-Lab/pmm-submodules` — separate PR triggers Jenkins FB images
