#!/usr/bin/env node
/**
 * screenshots — post-process Playwright screenshots into a
 * self-contained HTML report.
 *
 * Walks a Playwright test-results directory, collects every screenshot
 * (PNG or JPEG), converts PNGs to JPEG quality 80 to keep the bundle small
 * (3-10x smaller than PNG embeds), and emits one base64-embedded index.html.
 *
 * Requires `jimp` (pure-JS, no native deps). On first run, auto-installs it
 * to /tmp/.e2e-report-tools so the user's project node_modules stays clean.
 *
 * Usage:
 *   node report.js [--in test-results] [--out /tmp/e2e-report/index.html]
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const JPEG_QUALITY = 80;
const IMG_EXTS = new Set(['.png', '.jpg', '.jpeg']);

// --- jimp bootstrap ---------------------------------------------------------
// Lazy-install jimp into a shared /tmp cache dir, so multiple projects can
// reuse it and none of them get a stray node_modules entry.
const TOOLS_DIR = '/tmp/.e2e-report-tools';
function loadJimp() {
  try { return require('jimp'); } catch (_) {}
  try { return require(path.join(TOOLS_DIR, 'node_modules', 'jimp')); } catch (_) {}
  console.error('installing jimp into', TOOLS_DIR, '(one-time, ~5s)...');
  fs.mkdirSync(TOOLS_DIR, { recursive: true });
  if (!fs.existsSync(path.join(TOOLS_DIR, 'package.json'))) {
    fs.writeFileSync(path.join(TOOLS_DIR, 'package.json'), '{"private":true}');
  }
  execSync('npm install --silent --no-save --no-audit --no-fund jimp@^0.22', {
    cwd: TOOLS_DIR, stdio: 'inherit',
  });
  return require(path.join(TOOLS_DIR, 'node_modules', 'jimp'));
}
const Jimp = loadJimp();
// ----------------------------------------------------------------------------

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p));
    else if (entry.isFile() && IMG_EXTS.has(path.extname(p).toLowerCase())) out.push(p);
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
  for (const img of walk(inDir).sort()) {
    const rel = path.relative(inDir, img);
    const parts = rel.split(path.sep);
    const stem = path.basename(img, path.extname(img));
    if (parts.length >= 2) {
      shots.push([`${humanize(parts[0])} — ${stem}`, img]);
    } else {
      shots.push([stem, img]);
    }
  }
  return shots;
}

async function encodeAsJpeg(src) {
  const ext = path.extname(src).toLowerCase();
  if (ext === '.jpg' || ext === '.jpeg') {
    return fs.readFileSync(src).toString('base64');
  }
  const img = await Jimp.read(src);
  img.quality(JPEG_QUALITY);
  const buf = await img.getBufferAsync(Jimp.MIME_JPEG);
  return buf.toString('base64');
}

async function buildReport(shots, outPath) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });

  const nav = [];
  const sections = [];
  for (let idx = 0; idx < shots.length; idx++) {
    const [label, img] = shots[idx];
    const i = idx + 1;
    const data = await encodeAsJpeg(img);
    const anchor = `shot-${i}`;
    nav.push(
      `<a href="#${anchor}">${String(i).padStart(2, '0')}. ${esc(label)}</a>`,
    );
    sections.push(
      `<section id="${anchor}">` +
      `<h2>${String(i).padStart(2, '0')}. ${esc(label)}</h2>` +
      `<img src="data:image/jpeg;base64,${data}" alt="${esc(label)}">` +
      `</section>`,
    );
  }

  const html = `<!doctype html>
<html><head><meta charset="utf-8"><title>e2e screenshot report</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 24px; background: #0d1117; color: #c9d1d9;
         font: 14px/1.5 system-ui, -apple-system, sans-serif; }
  nav.toc { margin: 0 0 32px; padding: 16px;
            border: 1px solid #30363d; border-radius: 6px; }
  nav.toc a { display: block; color: #58a6ff; text-decoration: none;
              padding: 4px 0; font-size: 13px; }
  nav.toc a:hover { text-decoration: underline; }
  nav.toc h1, h2 { margin: 0 0 12px; font-size: 16px; color: #f0f6fc; }
  section { margin-bottom: 40px; }
  img { width: 100%; height: auto;
        border: 1px solid #30363d; border-radius: 6px; display: block; }
</style></head><body>
<nav class="toc"><h1>Contents</h1>${nav.join('')}</nav>
<main>${sections.join('')}</main>
</body></html>`;

  fs.writeFileSync(outPath, html);
  return outPath;
}

function parseArgs(argv) {
  const args = { inDir: 'test-results', outPath: '/tmp/e2e-report/index.html' };
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === '--in') args.inDir = argv[++i];
    else if (argv[i] === '--out') args.outPath = argv[++i];
    else if (argv[i] === '-h' || argv[i] === '--help') {
      console.log('usage: node report.js [--in test-results] [--out /tmp/e2e-report/index.html]');
      process.exit(0);
    } else {
      console.error(`unknown arg: ${argv[i]}`);
      process.exit(2);
    }
  }
  return args;
}

(async () => {
  const { inDir, outPath } = parseArgs(process.argv);
  if (!fs.existsSync(inDir) || !fs.statSync(inDir).isDirectory()) {
    console.error(`input directory not found: ${inDir}`);
    process.exit(1);
  }
  const shots = collect(inDir);
  if (!shots.length) {
    console.error(
      `no screenshots found under ${inDir} — check the tests produced PNGs/JPEGs, or pass --in <dir>`,
    );
    process.exit(1);
  }
  const out = await buildReport(shots, outPath);
  console.log(`report: ${out}  (${shots.length} screenshots, JPEG quality ${JPEG_QUALITY})`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
