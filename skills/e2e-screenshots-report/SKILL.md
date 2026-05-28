---
name: e2e-screenshots-report
description: >
  Generate a self-contained HTML report of e2e UI screenshots by running the
  project's existing Playwright tests with screenshots enabled and
  post-processing the output. Use when the user asks for an e2e screenshot
  report, a visual record of UI flows, a PR-ready visual of the running app,
  or invokes `/e2e-screenshots-report`. Playwright-only. Stops if the project
  has no Playwright tests.
---

# e2e-screenshots-report

Run the project's **existing** Playwright tests with `screenshot: 'on'`, then bundle the resulting PNGs into a single self-contained `index.html` (images base64-embedded). No parallel "capture script" to maintain — the report is literally the screenshots from the real test run, so it can't drift from what's tested.

## Invocation

```
/e2e-screenshots-report [--out PATH]
```

- `--out` (optional) — Path of the final HTML. Default `/tmp/e2e-report/index.html`.

## Step 1 — Locate the project's Playwright tests (or stop)

This skill works on **Playwright only** (JS/TS or Python). Detect which:

- **JS / TS:** `playwright.config.{ts,js,mjs}` exists at the repo root (or a subdir). Tests typically under `e2e/`, `tests/`, `tests/e2e/`, `*.spec.ts`.
- **Python:** `pytest-playwright` is a dependency (check `pyproject.toml` / `requirements*.txt`), or `conftest.py` imports `playwright`. Tests typically `test_*.py` under `tests/e2e/`.

If neither is present (Cypress, Selenium, no e2e suite), stop and tell the user this skill is Playwright-only.

## Step 2 — Bring the app up

The existing tests already know what URL to hit (via `playwright.config` `use.baseURL` for JS, or a project fixture for Python). Bring the app up at that URL before running tests:

1. Install the browser: `npx playwright install chromium` (JS) or `playwright install chromium` (Python).
2. Build / start the app per its README, Makefile, or any project-local `run` skill.
3. Bring up backing services (DB, seed data) the tests depend on.
4. Confirm reachable: `curl -sf <baseURL>` (from the config).

## Step 3 — Run the tests with screenshots enabled

The test runner produces one PNG per test under `test-results/<test-id>/`.

### JS / TS path — write a one-off override config

Create `playwright.screenshots.config.ts` (or `.js` / `.mjs` to match the project's config extension) next to the existing `playwright.config`. It extends the real config and adds `screenshot: 'on'`:

```ts
// playwright.screenshots.config.ts — temporary override, can be gitignored.
import { defineConfig } from '@playwright/test';
import base from './playwright.config';

export default defineConfig({
  ...base,
  use: { ...base.use, screenshot: 'on', trace: 'off', video: 'off' },
  reporter: 'list',
  outputDir: 'test-results',
});
```

If the project's `playwright.config` doesn't have a default export, adjust the import (e.g. `import { default as base } from './playwright.config'`).

Run the tests:

```bash
npx playwright test --config=playwright.screenshots.config.ts
```

### Python path — pytest-playwright flag

No config override needed; pytest-playwright exposes a CLI flag:

```bash
pytest --screenshot on --output test-results <test-path-or-marker>
```

(`--screenshot=on` writes `test-finished-1.png` per test under `test-results/<test-id>/`.)

### Either path

The run **does not need every test to pass**. Failing tests still produce screenshots and still belong in the report.

## Step 4 — Post-process into a single HTML

The bundled `report.py` walks the test-results directory, base64-embeds every PNG, and writes one self-contained HTML:

```bash
uv run report.py --in test-results --out /tmp/e2e-report/index.html
# or: python report.py --in test-results --out /tmp/e2e-report/index.html
```

The final stdout line is the report path. Tell the user where it is and offer to send the file — it's one HTML with no external assets, attachable to a PR.

## Step 5 — Make the labels meaningful (recommended for richer reports)

`screenshot: 'on'` captures **one PNG per test** (the final state). To get more granular shots without writing a parallel capture script, suggest the user add `await test.step("descriptive name", async () => { ... })` blocks inside their existing tests. Playwright records each step in the trace, and the screenshot file is named after the test so the report groups naturally. This is a normal Playwright pattern, not skill-specific.

## Common failure points

- **Tests didn't run** — wrong working directory, browsers not installed (`playwright install chromium`), app unreachable at `baseURL`.
- **No PNGs found** — JS path: override config not picked up (check `--config=` path and that `screenshot: 'on'` made it in). Python path: forgot `--screenshot on`.
- **Stale `test-results/`** — old screenshots from a prior run mixed with the current one. Delete the dir before re-running.
- **One screenshot per test feels thin** — see Step 5; add `test.step` blocks in the real tests.
- **Empty report** — `--in` pointed at the wrong directory. Confirm the path: it should contain `*/test-finished-*.png`.
