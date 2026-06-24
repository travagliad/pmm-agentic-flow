---
name: playwright-cli
description: Run Playwright E2E tests via CLI for the QA verifier agent. Token-efficient browser automation without MCP page dumps.
allowed-tools: Bash(playwright-cli:*), Bash(npx playwright:*)
---

# Playwright CLI (QA agent)

Use CLI commands instead of browser MCP for routine E2E work.

## Setup

```bash
npm ci
npx playwright install --with-deps chromium
```

## Authoring rules

- One expected value per assertion
- Test title = observable behavior
- Prefer `getByRole`, `getByTestId`, stable locators
- No `waitForTimeout` unless documented flake workaround

## Run and collect evidence

```bash
npx playwright test --reporter=html,list
npx playwright show-report
```

Artifacts to attach to the PR:

- `test-results/` (trace + video on failure)
- `playwright-report/` (HTML)

## playwright-cli quick ref

```bash
playwright-cli open https://localhost:8443
playwright-cli snapshot
playwright-cli click e15
playwright-cli close
```

Use snapshots to pick element refs; keep interactions minimal and deterministic.
