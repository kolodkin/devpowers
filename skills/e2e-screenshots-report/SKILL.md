---
name: e2e-screenshots-report
description: >
  Generate a self-contained HTML report of e2e UI screenshots by mirroring the
  project's existing e2e tests through a real browser. Use when the user asks
  for an e2e screenshot report, a visual record of UI flows, a PR-ready visual
  of the running app, or invokes `/e2e-screenshots-report`. Stops if the
  project has no e2e tests to mirror.
---

# e2e-screenshots-report

Drive the project's existing e2e UI flows through a real browser, capture labeled full-page screenshots at each step, and bundle them into one self-contained `index.html` (images embedded as base64). Output is PR-ready: one file, no external assets.

## Invocation

```
/e2e-screenshots-report [--base-url URL] [--out-dir DIR]
```

- `--base-url` (optional) — Where the app is served. Default `http://localhost:8000`.
- `--out-dir`  (optional) — Where to write the report. Default `/tmp/e2e-report`.

## Step 1 — Locate the project's e2e tests (or stop)

Flows come **only** from existing e2e tests; this skill never invents them. Search for:

- `e2e/`, `tests/e2e/`, `tests/integration/`
- `*.spec.ts`, `*.spec.js`, `*.cy.*`, `playwright.config.*`, `cypress.config.*`
- `test_*e2e*.py` and pytest-playwright fixtures

If nothing matches, stop and tell the user there are no e2e tests to mirror. Do not write speculative flows.

## Step 2 — Pick the template by e2e language

The skill ships two parallel templates that produce the same output:

| E2E test language | Template     | Runtime                                                                |
|-------------------|--------------|------------------------------------------------------------------------|
| Python            | `capture.py` | `uv run capture.py` (PEP-723 inline deps) or `pip install playwright` |
| JS / TS           | `capture.js` | `npm install playwright` then `node capture.js`                        |

Copy the chosen template into the project (e.g. `scripts/e2e_capture.py` or `scripts/e2e-capture.js`). Do **not** edit the project's real e2e test files — the capture script lives alongside them.

If the e2e suite mixes languages, pick the one that covers the flows being captured and tell the user which template was chosen.

## Step 3 — Mirror the e2e flows into the template

Read the selected e2e specs. For each flow, replicate its navigation and selectors into the template's `FLOWS` block, inserting `shot("label")` calls at meaningful checkpoints (after navigation, after each interaction worth showing, after async results render).

Keep the selectors **identical** to the e2e specs — `data-testid` attributes, role queries, text matchers. The report only mirrors what's tested if those selectors match.

Leave the capture engine and report builder (everything outside `--- customize per project ---`) untouched.

## Step 4 — Get the app reachable

Bring up the app at `--base-url` before running the capture:

1. Install the Playwright browser: `playwright install chromium` (Python) or `npx playwright install chromium` (Node).
2. Build / start the project per its README, Makefile, or any project-local `run` skill.
3. Bring up backing services (DB, seed data) the e2e specs depend on. Read the project's `Makefile`, `docker-compose.yml`, or the e2e setup script for the right invocations.
4. Confirm the app responds at the base URL: `curl -sf <base-url>`.

## Step 5 — Run the capture and surface the report

```bash
uv run scripts/e2e_capture.py --base-url http://localhost:8000 --out-dir /tmp/e2e-report
# or
node scripts/e2e-capture.js --base-url http://localhost:8000 --out-dir /tmp/e2e-report
```

The final line of stdout is the path to `index.html`. Tell the user where it is and offer to send the file (it's self-contained and attachable to a PR).

## Anti-drift — keep flows in sync with tests

Capture flows must mirror the e2e specs. When UI elements gain new `data-testid`s, when flows reorder, or when steps are added, update the template's `FLOWS` block to match. The report is only useful while it reflects what's actually tested.

When in doubt, re-read the e2e spec end-to-end and diff its actions against `FLOWS` before running.

## Common failure points

- **App unreachable** — server not started, wrong port, base URL typo. `curl -sf <base-url>` first.
- **Stale build** — frontend not rebuilt after recent edits. Re-run the project's build step.
- **Backing services down** — DB not running, seed step failed. Check the e2e spec's setup.
- **Playwright browser missing** — `playwright install chromium` (or `npx playwright install chromium`).
- **Selectors drifted** — the e2e specs changed but `FLOWS` didn't. Re-mirror Step 3.
- **Empty report** — `FLOWS` left as the placeholder. Replace it with the mirrored flows.
