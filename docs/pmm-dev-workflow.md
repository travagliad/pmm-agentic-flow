# PMM dev workflow (what human devs do)

Reference for the agent on `percona/pmm`. Full build runs inside the **devcontainer**; the control plane host runs **lint + targeted tests** before PR.

## Before opening or updating a PR

Human devs run (inside devcontainer):

```bash
make env-up
make env TARGET=prepare-pr   # gen + check-all + format — scoped by git
```

On the agent host (no devcontainer), run our script instead:

```bash
/projects/pmm-agentic-flow/src/sandbox/verify-pmm-change.sh /projects/pmm
```

## Code generation — do not spam `api/`

| Wrong | Right |
|-------|--------|
| `make gen` at repo root | Edit only your `.proto`, then `make -C api gen` if inventory/API changed |
| Commit hundreds of `*.pb.go` / `swagger.json` across unrelated APIs | Only generated files for the package you touched |
| Hand-edit `*.pb.go` | Change `.proto` and regenerate |

If `verify-pmm-change.sh` fails with too many `api/` files, reset those paths:

```bash
git checkout origin/main -- api/accesscontrol api/actions api/advisors  # example
```

## Lint (CI gate)

CI runs `make lint` (UI: `yarn lint` / eslint). The agent **must** run before PR:

```bash
make -C ui lint
```

Fix eslint errors (e.g. `react-hooks/rules-of-hooks`) — do not push and hope CI catches them.

## Full build

`make build` on the host often fails (CGO, pgquery, devcontainer-only paths). Preferred:

```bash
make env-up
make env TARGET=build
```

If devcontainer is not available, run targeted `go test` on changed packages and `make -C ui build` when UI changed.

## Functional smoke (before In Review)

See `docs/dev-smoke-test.md`. Dev agent must provision real DBs with `pmm-framework.py`, run a narrow functional smoke, then `--destroy`. Do not skip managed DB tests on the control plane.
