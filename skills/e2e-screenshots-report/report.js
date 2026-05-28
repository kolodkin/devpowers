#!/usr/bin/env node
/**
 * e2e-screenshots-report — post-process Playwright screenshots into a
 * self-contained HTML report.
 *
 * Walks a Playwright test-results directory, collects every PNG produced by
 * `screenshot: 'on'` (Playwright JS) or `--screenshot on` (pytest-playwright),
 * groups them by test, and emits one base64-embedded index.html.
 *
 * Zero deps — uses only Node stdlib.
 *
 * Usage:
 *   node report.js --in test-results [--out /tmp/e2e-report/index.html]
 */
const fs = require('fs');
const path = require('path');

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p));
    else if (entry.isFile() && p.toLowerCase().endsWith('.png')) out.push(p);
  }
  return out;
}

function humanize(testId) {
  const parts = testId.split(/[-_]+/);
  const browsers = new Set(['chromium', 'firefox', 'webkit']);
  let suffix = '';
  if (parts.length && browsers.has(parts[parts.length - 1].toLowerCase())) {
    suffix = ` (${parts.pop().toLowerCase()})`;
  }
  return parts.join(' ') + suffix;
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function collect(inDir) {
  const shots = [];
  for (const png of walk(inDir).sort()) {
    const rel = path.relative(inDir, png);
    const parts = rel.split(path.sep);
    const stem = path.basename(png, '.png');
    if (parts.length >= 2) {
      shots.push([`${humanize(parts[0])} — ${stem}`, png]);
    } else {
      shots.push([stem, png]);
    }
  }
  return shots;
}

function buildReport(shots, outPath) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });

  const nav = [];
  const sections = [];
  shots.forEach(([label, png], idx) => {
    const i = idx + 1;
    const data = fs.readFileSync(png).toString('base64');
    const anchor = `shot-${i}`;
    nav.push(
      `<a href="#${anchor}">${String(i).padStart(2, '0')}. ${esc(label)}</a>`,
    );
    sections.push(
      `<section id="${anchor}">` +
      `<h2>${String(i).padStart(2, '0')}. ${esc(label)}</h2>` +
      `<img src="data:image/png;base64,${data}" alt="${esc(label)}">` +
      `</section>`,
    );
  });

  const html = `<!doctype html>
<html><head><meta charset="utf-8"><title>e2e screenshot report</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; background: #0d1117; color: #c9d1d9;
         font: 14px/1.5 system-ui, -apple-system, sans-serif;
         display: grid; grid-template-columns: 280px 1fr; }
  nav { position: sticky; top: 0; height: 100vh; overflow: auto;
        padding: 16px; border-right: 1px solid #30363d; }
  nav a { display: block; color: #58a6ff; text-decoration: none;
          padding: 4px 0; font-size: 13px; }
  nav a:hover { text-decoration: underline; }
  main { padding: 24px; max-width: 1400px; }
  section { margin-bottom: 40px; }
  h2 { margin: 0 0 12px; font-size: 16px; color: #f0f6fc; }
  img { max-width: 100%; border: 1px solid #30363d; border-radius: 6px;
        display: block; }
</style></head><body>
<nav>${nav.join('')}</nav>
<main>${sections.join('')}</main>
</body></html>`;

  fs.writeFileSync(outPath, html);
  return outPath;
}

function parseArgs(argv) {
  const args = { inDir: null, outPath: '/tmp/e2e-report/index.html' };
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === '--in') args.inDir = argv[++i];
    else if (argv[i] === '--out') args.outPath = argv[++i];
    else if (argv[i] === '-h' || argv[i] === '--help') {
      console.log('usage: node report.js --in test-results [--out /tmp/e2e-report/index.html]');
      process.exit(0);
    } else {
      console.error(`unknown arg: ${argv[i]}`);
      process.exit(2);
    }
  }
  if (!args.inDir) {
    console.error('missing --in <dir>');
    process.exit(2);
  }
  return args;
}

const { inDir, outPath } = parseArgs(process.argv);
if (!fs.existsSync(inDir) || !fs.statSync(inDir).isDirectory()) {
  console.error(`input directory not found: ${inDir}`);
  process.exit(1);
}
const shots = collect(inDir);
if (!shots.length) {
  console.error(
    `no PNGs found under ${inDir} — did Playwright run with screenshot: 'on'?`,
  );
  process.exit(1);
}
const out = buildReport(shots, outPath);
console.log(`report: ${out}  (${shots.length} screenshots)`);
