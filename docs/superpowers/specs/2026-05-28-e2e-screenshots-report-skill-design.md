# e2e-screenshots-report skill — design

## Summary

A general-purpose devpowers skill that drives a project's existing e2e UI
flows through a real browser, captures labeled screenshots at each step, and
bundles them into a single self-contained `index.html` (images embedded as
base64). The output is a PR-ready visual record of the UI.

Modeled on the QueryView `e2e-screenshot-report` skill, but generalized so it
works in any web project instead of being hardwired to one app's build,
backing services, and selectors.

## Goals

- Produce one self-contained HTML report (no external assets) from a real
  browser session.
- Keep the report tied to the project's e2e test suite so it can't silently
  drift away from what's actually tested.
- Work across projects (different stacks, runners, serve commands) without
  edits to the skill itself.

## Non-goals

- Not a test runner or assertion framework — it captures, it does not verify.
- Does not author new e2e flows from scratch; it mirrors flows that already
  exist as tests.
- Does not modify the project's real e2e tests.

## Skill layout

```
skills/e2e-screenshots-report/
  SKILL.md        # runbook
  capture.py      # bundled fallback template (Python + Playwright)
```

Frontmatter `name: e2e-screenshots-report`, with a description that triggers on
phrases like "e2e screenshot report", "screenshot report", "capture UI
screenshots", "visual report of the app", and an explicit `/e2e-screenshots-report`
invocation.

## Behavior

### 1. Flow source — strictly from e2e tests

The skill first locates the project's e2e specs. Search common locations and
markers: `e2e/`, `tests/e2e/`, `*.spec.ts` / `*.spec.js`, `*.cy.*`,
`test_*e2e*.py`, `playwright.config.*`, `cypress.config.*`.

- If **no** e2e specs are found, the skill **stops** and tells the user there
  is nothing to mirror (and that this skill derives flows only from existing
  e2e tests).
- If specs are found, Claude reads them to extract: the flows, their
  navigation order, the selectors / `data-testid`s used, and any required
  setup (seed data, auth, fixtures). These become the capture steps.

### 2. Runner — detect, then fall back

- **Reuse path:** If the project already has a Playwright runner (JS/TS via
  `playwright.config.*`, or Python via the `playwright` package), Claude adds a
  **separate** capture spec/script that reuses the project's config and
  selectors. It never edits the real test files.
- **Fallback path:** If there is no reusable Playwright setup (e.g. the e2e
  suite is Cypress, or there's no browser runner wired for screenshotting),
  Claude copies the bundled `capture.py` template into a working location and
  fills in the per-project parts. Run via `uv run capture.py ...` (or a venv +
  `pip install playwright`), preceded by `playwright install chromium`.

In both paths the capture program reuses the *selectors and navigation* learned
from the e2e specs — the report mirrors the tests.

**Report assembly is shared.** The HTML report builder in `capture.py` can run
standalone over a directory of numbered PNGs plus a small label manifest
(`capture.py --report-only --out-dir <dir>`). So the JS/TS reuse path only has
to produce the labeled PNGs; it then calls the bundled report builder to emit
the final `index.html`. This keeps a single, generic report implementation
regardless of which runner captured the screenshots.

### 3. Preconditions (generalized)

SKILL.md walks Claude through getting the app into a screenshot-able state:

1. Determine the project's build command and serve/start command (reuse a
   project `run`/start skill if one exists; otherwise infer from
   `package.json`, `Makefile`, `docker-compose.yml`, README).
2. Bring up any backing services the e2e specs depend on (DB, seed data) — the
   skill names this as a step but defers the concrete commands to the project.
3. Start the app and confirm it's reachable at a base URL (default
   configurable, e.g. `http://localhost:<port>`).
4. Install the Playwright browser (`playwright install chromium`).
5. Run the capture program.

### 4. Output

A self-contained `index.html` written to a temp dir, default
`/tmp/<repo>-e2e-report/index.html`:

- Dark-themed layout with a sidebar navigation listing each labeled
  screenshot.
- Full-page screenshots, sequentially numbered, embedded as base64 data URIs
  so the single file is portable (attachable to a PR, openable anywhere).
- A header noting the source flows and capture timestamp.

The HTML-generation code in `capture.py` is generic and reused verbatim across
projects. Only the configuration block (base URL, output dir) and the flow
definitions (ordered steps + screenshot labels) are marked
`# --- customize per project ---`.

### 5. Maintenance / anti-drift note

SKILL.md includes a prominent note: when UI elements gain new `data-testid`s or
flows change, the capture steps must be updated to match the e2e specs, exactly
as the reference skill warns. The report is only trustworthy while it mirrors
the tests.

### 6. Common failure points

Documented in SKILL.md for triage:

- App unreachable at the base URL / server not started.
- Stale build (frontend not rebuilt after changes).
- Backing services down or seed step failed.
- Playwright browser not installed (`playwright install chromium`).
- Selectors in the e2e specs changed and the capture steps drifted.

## Template (`capture.py`) shape

A standalone Python + Playwright (sync API) script:

- **Config block** (customize): `BASE_URL`, `OUT_DIR`.
- **Flow definitions** (customize): a small structure of named flows, each a
  list of `(action, label)` steps where a labeled step triggers a full-page
  screenshot.
- **Capture engine** (generic): launches headless Chromium, runs each flow,
  saves numbered PNGs.
- **Report builder** (generic): reads numbered PNGs + a `labels.json` manifest
  from the out-dir, base64-embeds the images, and emits the dark-themed
  `index.html` with sidebar nav. Exposed as a `--report-only` mode so it can
  assemble a report from PNGs produced by an external (JS/TS) runner.
- Invoked via `uv run capture.py --base-url ... --out-dir ...` (full
  capture+report) or `uv run capture.py --report-only --out-dir ...`
  (report from existing PNGs), with sensible defaults so it also runs under a
  plain `python capture.py`.

The bundled template ships with one tiny placeholder flow (a single page load +
screenshot) clearly marked for replacement, so it runs out-of-the-box and
demonstrates the structure without pretending to know any real app's flows.

## Conventions (per repo CLAUDE.md)

- Reference `capture.py` from SKILL.md with a plain relative path
  (`capture.py`), not `${CLAUDE_PLUGIN_ROOT}`, so it resolves for both plugin
  and project-level installs.
- Keep the skill self-contained under `skills/e2e-screenshots-report/`.

## Open questions

None blocking. README skill-list update is optional and can be folded into the
implementation plan.
