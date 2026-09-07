// Run with Playwright installed: node scripts/check-icons.cjs
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(pathToFileURL(path.resolve(__dirname, '../index.html')).href);
    assert.equal(await page.locator('article').count(), 5);
    assert.equal(await page.locator('img').count(), 20);
    await page.locator('img').evaluateAll(images => Promise.all(images.map(image => image.decode())));
    for (const link of await page.locator('.download').all()) {
      const svg = decodeURIComponent((await link.getAttribute('href')).split(',')[1]);
      assert.ok(svg.includes('viewBox="0 0 256 256"'));
      assert.equal(await page.evaluate(source => new DOMParser().parseFromString(source, 'image/svg+xml').querySelector('parsererror')?.textContent ?? null, svg), null);
      const pending = page.waitForEvent('download');
      await link.click();
      const download = await pending;
      assert.match(download.suggestedFilename(), /^notic-[a-z-]+\.svg$/);
      assert.equal(await download.failure(), null);
    }
    await page.screenshot({ path: '/tmp/notic-icons-desktop.png', fullPage: true });
    await page.getByRole('button', { name: 'Dark', exact: true }).click();
    assert.equal(await page.getByRole('button', { name: 'Dark', exact: true }).getAttribute('aria-pressed'), 'true');
    assert.ok(await page.locator('body').evaluate(body => body.classList.contains('dark')));
    await page.screenshot({ path: '/tmp/notic-icons-dark.png', fullPage: true });
    await page.getByRole('button', { name: 'Light', exact: true }).click();
    assert.equal(await page.getByRole('button', { name: 'Light', exact: true }).getAttribute('aria-pressed'), 'true');
    for (const width of [1440, 900, 390, 320]) {
      await page.setViewportSize({ width, height: 900 });
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `Overflow at ${width}px`);
    }
    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: '/tmp/notic-icons-mobile.png', fullPage: true });
    assert.deepEqual(errors, []);
    console.log('PASS: 5 icons, 20 previews, valid SVGs, 5 downloads, light/dark controls, 4 viewport widths; no page errors.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
