// Debug helper: screenshots of the add animation at fixed times.
import puppeteer from 'puppeteer-core';
const [out, id] = process.argv.slice(2);
const b = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
const p = await b.newPage();
p.on('console', (m) => { if (['error', 'warn'].includes(m.type()) || /error|exception/i.test(m.text())) console.log('console', m.type(), m.text().slice(0, 300)); });
p.on('pageerror', (e) => console.log('pageerror', e.message.slice(0, 300)));
await p.emulate({ viewport: { width: 375, height: 812, deviceScaleFactor: 1, isMobile: true, hasTouch: true }, userAgent: 'Mozilla/5.0 (Linux; Android 13) Mobile' });
await p.goto(`https://menova-80602.web.app/product/${id}`, { waitUntil: 'load', timeout: 90000 });
// Wait until the app has drawn the product (screenshot no longer blank).
for (let i = 0; i < 60; i++) {
  const shot = await p.screenshot({ encoding: 'base64', clip: { x: 0, y: 200, width: 375, height: 100 } });
  if (shot.length > 3000) break;
  await new Promise((r) => setTimeout(r, 1000));
}
await new Promise((r) => setTimeout(r, 4000));
await p.screenshot({ path: `${out}/f_before.png`, clip: { x: 0, y: 60, width: 375, height: 480 } });
const t0 = Date.now();
await p.touchscreen.tap(187, 773);
for (const at of [1300, 1450, 2100, 2200, 2300, 2400]) {
  const wait = at - (Date.now() - t0);
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  await p.screenshot({ path: `${out}/f_${at}.png`, clip: { x: 0, y: 60, width: 375, height: 480 } });
}
await b.close();
