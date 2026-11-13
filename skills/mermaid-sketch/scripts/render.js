// render.js <diagram.mmd> <out.png> - prints OK or ERR <parser message>, exits 0 or 1
const fs = require('fs');
const { chromium } = require('playwright');
(async () => {
  const src = fs.readFileSync(process.argv[2], 'utf8');
  const html = `<html><body><pre class="mermaid">${src
    .replace(/&/g, '&amp;').replace(/</g, '&lt;')}</pre>
    <script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js"></script>
    <script>mermaid.initialize({ startOnLoad: false });
      mermaid.run().then(() => document.title = 'OK')
        .catch(e => document.title = 'ERR ' + e.message)</script></body></html>`;
  const b = await chromium.launch();
  const p = await b.newPage({ deviceScaleFactor: 2 });
  await p.setContent(html);
  await p.waitForFunction(() => document.title !== '', { timeout: 20000 });
  const title = await p.title();
  // crop to the diagram when it rendered, whole page when it did not
  await (title === 'OK' ? p.locator('svg').first() : p).screenshot({ path: process.argv[3] });
  await b.close();
  console.log(title);
  process.exit(title === 'OK' ? 0 : 1);
})();
