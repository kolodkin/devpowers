---
name: e2e-screenshots-report
description: >
  Run the project's existing Playwright tests, collect the screenshots they
  write (inline `page.screenshot()` calls by default; `screenshot: 'on'` per
  test if invoked with `--screenshot-on`), and bundle them into a single
  self-contained `index.html`. Use when the user asks for an e2e screenshot
  report, a visual record of UI flows, a PR-ready visual of the running app,
  or invokes `/e2e-screenshots-report`. Playwright-only.
---

# e2e-screenshots-report

Three steps.

## Invocation

```
/e2e-screenshots-report [--in DIR] [--out PATH] [--screenshot-on]
```

- `--in` — directory the project's tests write screenshots to. Default: detect it (`test-results/`, `screenshots/`, or whatever the tests' `page.screenshot({ path: ... })` calls use).
- `--out` — output HTML path. Default `/tmp/e2e-report/index.html`.
- `--screenshot-on` — additionally force Playwright to save a final-state PNG per test (uses the override config / `--screenshot on` flag). Off by default.

## 1. Run the project's e2e tests

If the project has no Playwright tests (no `playwright.config.*` and no `pytest-playwright`), stop and tell the user.

**Default** — run the tests as-is and harvest the screenshots they already take inline:

```bash
npx playwright test     # JS
pytest                   # Python
```

Identify where those screenshots land. Grep test files for `page.screenshot(` (JS/TS) or `page.screenshot(` (Python) to find the path argument. Common destinations: `test-results/`, `screenshots/`, `playwright-report/`.

**With `--screenshot-on`** — additionally turn on Playwright's per-test final-state PNG:

JS / TS — write `playwright.screenshots.config.ts` next to the existing `playwright.config`:

```ts
import { defineConfig } from '@playwright/test';
import base from './playwright.config';
export default defineConfig({
  ...base,
  use: { ...base.use, screenshot: 'on' },
  outputDir: 'test-results',
});
```

Then run:

```bash
npx playwright test --config=playwright.screenshots.config.ts
```

Python (pytest-playwright):

```bash
pytest --screenshot on --output test-results
```

Failing tests still produce PNGs and still belong in the report.

## 2. Run the capture script

Pick the runtime that matches the project — both scripts produce the same self-contained HTML:

**JS / TS projects** (Node already available):

```bash
node report.js --in <screenshots-dir> --out /tmp/e2e-report/index.html
```

**Python projects:**

```bash
uv run report.py --in <screenshots-dir> --out /tmp/e2e-report/index.html
# or: python report.py --in <screenshots-dir> --out /tmp/e2e-report/index.html
```

## 3. Deliver the report

Send `/tmp/e2e-report/index.html` to the user with the `SendUserFile` tool. It's a single self-contained HTML (base64-embedded images), attachable to a PR.
