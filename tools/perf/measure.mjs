// P1-B06 / P1-H04: frame timing of the live builder in headless Chrome,
// emulating a mid-range phone (375x812 @2x) with the CPU slowed 4x.
// Owner decision: measure in the browser with emulation until real devices
// are available; numbers are an approximation, not a device report.
//
// Usage (from tools/perf/): npm install && npm run measure
//   SITE=https://menova-80602.web.app CPU=4 npm run measure
import puppeteer from 'puppeteer-core';

const site = process.env.SITE ?? 'https://menova-80602.web.app';
const cpu = Number(process.env.CPU ?? 4);
const chrome =
  process.env.CHROME ??
  'C:/Program Files/Google/Chrome/Application/chrome.exe';

// Heaviest real case: veggie, large, stuffed crust, every topping at
// default + maxQty (504 pieces; see piece_count_test.dart).
const heavy = {
  lines: [{
    lineId: 'perf', qty: 1,
    selection: {
      productId: 'pizza_veggie', categoryId: 'pizza', definitionVersion: 1,
      sizeId: 'l', options: { crust: 'stuffed_crust' }, notes: '',
      ingredients: Object.fromEntries(
        ['mozzarella', 'bell_pepper_green', 'bell_pepper_red', 'mushroom',
          'onion', 'tomato', 'olive_black', 'corn'].map((i) => [i, 3])),
    },
  }],
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function stats(frames, longTasks) {
  const f = frames.slice(2);
  const s = [...f].sort((a, b) => a - b);
  const p = (q) => s[Math.floor(q * (s.length - 1))];
  const avg = f.reduce((a, b) => a + b, 0) / f.length;
  return {
    frames: f.length,
    avgFps: +(1000 / avg).toFixed(1),
    p50ms: +p(0.5).toFixed(1),
    p95ms: +p(0.95).toFixed(1),
    maxMs: +s[s.length - 1].toFixed(1),
    jank17: f.filter((x) => x > 17.5).length,
    jank34: f.filter((x) => x > 34).length,
    longTasks,
  };
}

async function record(page, ms, action) {
  await page.evaluate(() => {
    window.__f = []; window.__lt = 0; window.__rec = true;
    new PerformanceObserver((l) => { window.__lt += l.getEntries().length; })
      .observe({ type: 'longtask' });
    let last = performance.now();
    const loop = (t) => {
      if (!window.__rec) return;
      window.__f.push(t - last); last = t; requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  });
  if (action) await action();
  await sleep(ms);
  const { f, lt } = await page.evaluate(() => {
    window.__rec = false; return { f: window.__f, lt: window.__lt };
  });
  return stats(f, lt);
}

async function open(browser, path, cart) {
  const page = await browser.newPage();
  await page.emulate({
    viewport: { width: 375, height: 812, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
    userAgent: 'Mozilla/5.0 (Linux; Android 13; Pixel 6a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
  });
  if (cart) {
    await page.evaluateOnNewDocument((raw) => {
      localStorage.setItem('flutter.cart.v1', raw);
    }, JSON.stringify(JSON.stringify(cart)));
  }
  const cdp = await page.createCDPSession();
  await page.goto(`${site}${path}`, { waitUntil: 'networkidle0', timeout: 90000 });
  await sleep(4000); // Images decoded, first animations settled.
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
  return page;
}

// Heaviest real case built with real taps on the 375px layout: large size,
// then two extra units of each of the 8 veggie toppings (504 pieces). Tap
// positions come from the page layout at the given scroll offsets.
async function buildHeavy(page) {
  const tap = async (x, y, n = 1) => {
    for (let i = 0; i < n; i++) {
      await page.touchscreen.tap(x, y);
      await sleep(350);
    }
  };
  const scroll = async (dy) => {
    await page.mouse.move(187, 400);
    await page.mouse.wheel({ deltaY: dy });
    await sleep(900);
  };
  await scroll(600);
  await tap(273, 187); // Large
  await tap(78, 455, 2); // Mozzarella
  await tap(214, 455, 2); // Black olives
  await scroll(600);
  for (const [x, y] of [[78, 155], [214, 155], [78, 325], [214, 325], [78, 495], [214, 495]]) {
    await tap(x, y, 2);
  }
  await scroll(-1200);
  await sleep(2500); // Let every enter animation finish.
}

// The add/update bar sits at the bottom of the product page.
const tapAdd = (page) => () => page.touchscreen.tap(187, 773);

const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: true,
  args: ['--enable-gpu-rasterization', '--ignore-gpu-blocklist'],
});
try {
  const results = {};
  // Each add runs twice on the same page: the first pays one-time costs
  // (decoding oven frames, first snapshot), the second is the steady state.
  const twice = async (label, path, setup) => {
    const page = await open(browser, path, null);
    if (setup) {
      await setup(page);
      results[`${label}: idle`] = await record(page, 2000);
    }
    results[`${label}: add #1 (cold)`] = await record(page, 5000, tapAdd(page));
    results[`${label}: add #2 (warm)`] = await record(page, 5000, tapAdd(page));
    if (setup) {
      await page.screenshot({ path: process.env.SHOT ?? 'heavy.png' });
    }
    await page.close();
  };
  await twice('heavy veggie L max (504 pieces)', '/product/pizza_veggie', buildHeavy);
  await twice('veggie default (8 toppings)', '/product/pizza_veggie');
  await twice('margherita default', '/product/pizza_margherita');

  console.log(JSON.stringify({ site, cpuThrottle: `${cpu}x`, results }, null, 2));
} finally {
  await browser.close();
}
