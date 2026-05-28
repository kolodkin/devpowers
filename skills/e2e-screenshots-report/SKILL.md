---
name: e2e-screenshots-report
description: >
  Run the project's existing Playwright tests with screenshots enabled, bundle
  the resulting PNGs into a single self-contained `index.html`, and deliver it.
  Use when the user asks for an e2e screenshot report, a visual record of UI
  flows, a PR-ready visual of the running app, or invokes
  `/e2e-screenshots-report`. Playwright-only.
---

# e2e-screenshots-report

Three steps.

## 1. Run Playwright with screenshots on

If the project has no Playwright tests (no `playwright.config.*` and no `pytest-playwright`), stop and tell the user.

**JS / TS** — write `playwright.screenshots.config.ts` next to the existing `playwright.config`:

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

**Python (pytest-playwright):**

```bash
pytest --screenshot on --output test-results
```

Failing tests still produce PNGs and still belong in the report.

## 2. Run the capture script

```bash
uv run report.py --in test-results --out /tmp/e2e-report/index.html
```

(or `python report.py --in test-results --out /tmp/e2e-report/index.html` if `uv` isn't available).

## 3. Deliver the report

Send `/tmp/e2e-report/index.html` to the user with the `SendUserFile` tool. It's a single self-contained HTML (base64-embedded images), attachable to a PR.
