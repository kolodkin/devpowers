#!/usr/bin/env node
/**
 * e2e-screenshots-report capture template (Node + Playwright).
 *
 * Drives the project's e2e UI flows in a headless browser, captures labeled
 * full-page screenshots at each step, and bundles them into a self-contained
 * index.html (images embedded as base64).
 *
 * The FLOWS block below must mirror the project's e2e test specs. When the
 * specs change (new data-testids, new steps, reorderings), update FLOWS to
 * match — otherwise the report drifts from what's actually tested.
 *
 * Usage:
 *   node capture.js [--base-url URL] [--out-dir DIR]
 *
 * Prereqs:
 *   npm install playwright
 *   npx playwright install chromium
 */
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

// --- customize per project ---------------------------------------------------

const BASE_URL = 'http://localhost:8000';
const OUT_DIR = '/tmp/e2e-report';

async function flowLanding(page, shot, baseUrl) {
  // Placeholder flow — replace with steps mirrored from your e2e tests.
  await page.goto(baseUrl);
  await shot('landing page');
  // Example:
  // await page.click('[data-testid="login-button"]');
  // await page.fill('[data-testid="email"]', 'user@example.com');
  // await shot('login form filled');
}

const FLOWS = [
  ['landing', flowLanding],
  // ['query', flowQuery],
  // ['settings', flowSettings],
];

// --- end customize ----------------------------------------------------------

const slug = (s) =>
  s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'shot';

const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]),
  );

async function capture(baseUrl, outDir) {
  fs.mkdirSync(outDir, { recursive: true });
  const shots = [];
  const browser = await chromium.launch();
  try {
    for (const [flowName, flowFn] of FLOWS) {
      const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
      const shot = async (label) => {
        const idx = shots.length + 1;
        const file = path.join(
          outDir,
          `${String(idx).padStart(3, '0')}-${flowName}-${slug(label)}.png`,
        );
        await page.screenshot({ path: file, fullPage: true });
        shots.push([`${flowName}: ${label}`, file]);
      };
      await flowFn(page, shot, baseUrl);
      await page.close();
    }
  } finally {
    await browser.close();
  }
  return shots;
}

function buildReport(shots, outDir) {
  const nav = shots
    .map(([label], i) => `<a href="#shot-${i + 1}">${String(i + 1).padStart(2, '0')}. ${esc(label)}</a>`)
    .join('');
  const sections = shots
    .map(([label, file], i) => {
      const data = fs.readFileSync(file).toString('base64');
      return (
        `<section id="shot-${i + 1}">` +
        `<h2>${String(i + 1).padStart(2, '0')}. ${esc(label)}</h2>` +
        `<img src="data:image/png;base64,${data}" alt="${esc(label)}">` +
        `</section>`
      );
    })
    .join('');

  const html = `<!doctype html>
<html><head><meta charset="utf-8"><title>e2e screenshot report</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; background: #0d1117; color: #c9d1d9;
         font: 14px/1.5 system-ui, -apple-system, sans-serif;
         display: grid; grid-template-columns: 260px 1fr; }
  nav { position: sticky; top: 0; height: 100vh; overflow: auto;
        padding: 16px; border-right: 1px solid #30363d; }
  nav a { display: block; color: #58a6ff; text-decoration: none; padding: 4px 0; font-size: 13px; }
  nav a:hover { text-decoration: underline; }
  main { padding: 24px; max-width: 1400px; }
  section { margin-bottom: 40px; }
  h2 { margin: 0 0 12px; font-size: 16px; color: #f0f6fc; }
  img { max-width: 100%; border: 1px solid #30363d; border-radius: 6px; display: block; }
</style></head><body>
<nav>${nav}</nav>
<main>${sections}</main>
</body></html>`;

  const report = path.join(outDir, 'index.html');
  fs.writeFileSync(report, html);
  return report;
}

function parseArgs(argv) {
  const args = { baseUrl: BASE_URL, outDir: OUT_DIR };
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === '--base-url') args.baseUrl = argv[++i];
    else if (argv[i] === '--out-dir') args.outDir = argv[++i];
    else if (argv[i] === '-h' || argv[i] === '--help') {
      console.log('usage: node capture.js [--base-url URL] [--out-dir DIR]');
      process.exit(0);
    } else {
      console.error(`unknown arg: ${argv[i]}`);
      process.exit(2);
    }
  }
  return args;
}

(async () => {
  const { baseUrl, outDir } = parseArgs(process.argv);
  const shots = await capture(baseUrl, outDir);
  if (!shots.length) {
    console.error('no screenshots captured — check your FLOWS definition');
    process.exit(1);
  }
  const report = buildReport(shots, outDir);
  console.log(`report: ${report}  (${shots.length} screenshots)`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
