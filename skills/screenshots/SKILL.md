---
name: screenshots
description: >
  Run the project's existing Playwright tests and bundle their screenshots into
  a single self-contained `index.html`. Use when the user asks for an e2e
  screenshot report, a visual record of UI flows, a PR-ready visual of the
  running app, or invokes `/screenshots`. Playwright-only.
---

# screenshots

Three steps.

## Invocation

```
/screenshots [--in DIR] [--out PATH] [--screenshot-on]
```

- `--in` — directory the project's tests write screenshots to. Default `test-results/` (Playwright JS and pytest-playwright convention). Pass an explicit path if the project writes elsewhere.
- `--out` — output HTML path. Default `/tmp/e2e-report/index.html`.
- `--screenshot-on` — additionally force Playwright to save a final-state PNG per test (uses the override config / `--screenshot on` flag). Off by default.

## 1. Run the project's e2e tests

If the project has no Playwright tests (no `playwright.config.*` and no `pytest-playwright`), stop and tell the user.

**Default** — run the tests as-is and harvest the screenshots they already take inline:

```bash
npx playwright test     # JS
pytest                   # Python
```

Screenshots land in `test-results/` by default. If the project writes elsewhere, pass `--in <dir>`.

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

Both scripts convert PNG screenshots to JPEG (quality 80) before base64-embedding — a single `index.html` of 30 screenshots is ~3 MB instead of ~30 MB. JPEG inputs are passed through.

Pick the runtime that matches the project:

**JS / TS projects** (Node already available):

```bash
node report.js --out /tmp/e2e-report/index.html
```

First run auto-installs `jimp` (pure-JS, no native deps) into `/tmp/.e2e-report-tools` — shared across projects, your `node_modules` stays clean.

**Python projects:**

```bash
uv run report.py --out /tmp/e2e-report/index.html
# or: python report.py --out /tmp/e2e-report/index.html  (after `pip install Pillow`)
```

`uv run` resolves Pillow automatically via the inline PEP-723 dep block.

Both default `--in` to `test-results/`. Pass `--in <dir>` if the project writes screenshots somewhere else.

## 3. Deliver the report

Send `/tmp/e2e-report/index.html` to the user with the `SendUserFile` tool. It's a single self-contained HTML (base64-embedded images), attachable to a PR.
