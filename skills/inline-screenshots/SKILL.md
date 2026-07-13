---
name: inline-screenshots
description: >
  Add screenshot capture inside existing Playwright tests. Use when the user
  wants tests to record what the UI renders, when a screenshot report would be
  empty because tests take no screenshots, or when the screenshots skill offers
  instrumentation. Playwright-only (JS/TS and pytest-playwright).
---

# inline-screenshots

Add curated `page.screenshot()` calls inside existing Playwright tests so each visual behavior is captured at its proving moment. The mechanics are trivial — placement, curation, and naming are what make the resulting report worth reading.

Instrumenting means editing the user's test files: propose it, don't do it unasked.

## Mechanics

JS / TS — use the test's output dir, so files land under `test-results/` in a directory named after the spec file:

```ts
test('freeze powerup pauses enemies', async ({ page }, testInfo) => {
  // ...
  await page.screenshot({ path: testInfo.outputPath('enemies-frozen.png') });
```

Python (pytest-playwright):

```python
page.screenshot(path=f"test-results/{Path(__file__).stem}/enemies-frozen.png")
```

Not `testInfo.attach()` — Playwright persists attachments under content-hash filenames, so a report that captions by filename shows hashes, and the PNGs land outside the per-test directories harvest filters expect.

## Placement rules

- **Shoot at the proving moment** — immediately *after* the assertion or wait that establishes the state: after `waitForFunction(frozen)`, not after the thaw; while the pickup floats, not once it's collected. After-the-assert also means a failing test never blames the screenshot.
- **Curate, don't blanket** — one shot per visual behavior, not per test. Every distinct scene/theme, visual effect, overlay/screen state, and responsive layout gets one; pure-logic tests (score math, ammo counting) get none. Skip "after" shots of a return to the normal state.
- **Name for the caption** — report generators use filenames as captions: descriptive kebab-case (`frozen-ogre.png`, `stage-volcano.png`), never `test_17_final.png`.
- **Keep the test file's stem in the path** (`testInfo.outputPath` and the Python pattern above both do) — session-scoped report filters match screenshot paths against test-file stems, and shots that drop the stem silently vanish from the report.
- **Stay out of tight loops** — each shot costs ~50–100 ms (more on software renderers) and joins the test's timing budget; never capture inside a wait/poll loop.

## Before finishing

Confirm the screenshot dir (`test-results/` by convention) is gitignored — inline shots run on every plain `npx playwright test` / `pytest`, not just report runs.
