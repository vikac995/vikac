// Usage: node test.js [out-dir] [id-filter] [html-file]  — loads index.html, reports console errors, screenshots each plate.
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const out = process.argv[2] || '/tmp/claude-0/-home-user-vikac/f38cf995-f133-52b6-9eb6-07875219a6e3/scratchpad/shots';
  const only = process.argv[3];
  const file = process.argv[4] || 'index.html';
  const b = await chromium.launch();
  for (const [name, vp, scheme] of [['phone', { width: 400, height: 860 }, 'light'], ['desk', { width: 1280, height: 900 }, 'dark']]) {
    const p = await b.newPage({ viewport: vp, colorScheme: scheme });
    const errs = [];
    p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
    p.on('pageerror', e => errs.push('PAGEERROR ' + e.message));
    await p.goto('file://' + path.resolve(__dirname, file));
    await p.waitForTimeout(900);
    const ids = await p.$$eval('.plate', els => els.map(e => e.id));
    const sw = await p.evaluate(() => document.documentElement.scrollWidth);
    console.log(name, 'plates', ids.length, 'scrollWidth', sw, 'errors', errs);
    for (const id of ids) {
      if (only && !id.includes(only)) continue;
      const el = await p.$('#' + id);
      await el.scrollIntoViewIfNeeded(); await p.waitForTimeout(250);
      await el.screenshot({ path: `${out}/${name}-${id}.png` });
    }
    await p.close();
  }
  await b.close();
})();
