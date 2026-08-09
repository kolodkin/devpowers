---
name: screenshots
description: >
  Run the project's existing Playwright tests and deliver their screenshots.
  Use when the user asks for an e2e screenshot report, a visual record of UI
  flows, a PR-ready visual of the running app, wants test screenshots shown
  directly in the chat, or invokes `/screenshots`. Playwright-only.
---

# screenshots

Four steps.

## Invocation

```
/screenshots [all] [--in DIR] [--out PATH] [--screenshot-on]
```

- `all` — run the full test suite and report every screenshot. Without it, the report is scoped to the tests worked on in this session (step 1).
- `--in` — directory the project's tests write screenshots to. Default `test-results/` (Playwright JS and pytest-playwright convention). Pass an explicit path if the project writes elsewhere.
- `--out` — output HTML path. Default `/tmp/e2e-report/index.html`.
- `--screenshot-on` — additionally force Playwright to save a final-state PNG per test (uses the override config / `--screenshot on` flag). Off by default.

## 1. Pick the scope

**Default (session scope)** — the report demonstrates what was worked on this session, not the whole suite. List the session's tests from:

1. Test files you created or modified in this conversation.
2. Test files changed on the branch: `git status --porcelain` plus `git diff --name-only $(git merge-base HEAD origin/HEAD 2>/dev/null || echo HEAD)` — keep the test files (`*.spec.*`, `*.test.*`, `test_*.py`, files under `tests/` / `e2e/`).

If the list is empty — nothing test-related was touched this session — fall back to the full suite (same as `all`) and say so when delivering the report.

**With `all`** — full suite, no filtering; skip to step 2.

## 2. Run the e2e tests

If the project has no Playwright tests (no `playwright.config.*` and no `pytest-playwright`), stop and tell the user.

Run the tests as-is and harvest the screenshots they already take inline — only the session's test files in session scope, everything with `all`:

```bash
npx playwright test tests/login.spec.ts tests/signup.spec.ts   # JS, session scope
npx playwright test                                             # JS, all
pytest tests/test_login.py                                      # Python, session scope
pytest                                                          # Python, all
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

## 3. Run the capture script

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

In session scope, also pass `--filter` — a case-insensitive regex matched against each screenshot's path relative to `--in`. Build it from the session test files' basename stems joined with `|` (Playwright test-id directories are dash-joined, so a stem like `login` matches `specs-login-Login-flow-chromium`; for stems with `_` or `.`, use `[-_.]` between words — `test_login.py` → `test[-_.]login`):

```bash
node report.js --out /tmp/e2e-report/index.html --filter 'login|signup'
```

The filter also keeps stale screenshots from earlier full-suite runs out of the report — `test-results/` isn't cleaned between runs. If it matches nothing, the script exits 1 with a message; loosen the regex or fall back to no filter. Omit `--filter` for `all`.

## 4. Deliver

Two `SendUserFile` calls — the relevant screenshots render inline in the chat, and the report rides along as an attachment:

1. **Inline images** — the screenshot files under `--in` that made it into the report (in session scope, paths matching step 3's `--filter` regex; with `all`, everything). Send them in one call with `display: 'render'` and a caption naming the tests they came from. If more than 12 match, skip this call and say so — the report has them all.
2. **Report** — `/tmp/e2e-report/index.html` with `display: 'attach'`. A single self-contained HTML (base64-embedded images), attachable to a PR.
