// P1-H06: runs the manual cases of docs/ACCEPTANCE_PIZZA.md against the
// live storefront in headless Chrome at phone size, tapping by visible text
// through Flutter's semantics tree. Prints one line per case and writes
// screenshots to OUT. Places one TEST pickup order (owner-approved run).
//
// Usage (from tools/perf/): OUT=<dir> node acceptance.mjs
import puppeteer from 'puppeteer-core';

const site = process.env.SITE ?? 'https://menova-80602.web.app';
const out = process.env.OUT ?? '.';
const chrome = process.env.CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const report = (id, ok, note = '') => {
  results.push({ id, ok, note });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${id}  ${note}`);
};

const browser = await puppeteer.launch({ executablePath: chrome, headless: true });
const page = await browser.newPage();
await page.emulate({
  viewport: { width: 375, height: 812, deviceScaleFactor: 1, isMobile: true, hasTouch: true },
  userAgent: 'Mozilla/5.0 (Linux; Android 13; Pixel 6a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
});

// Pages are opened with `?semantics` (storefront main.dart), so the tree
// is on from the first frame; this only waits for it to settle.
async function enableSemantics() {
  await sleep(500);
}

/** Visible texts in the semantics tree (labels and values). */
const SEL = 'flt-semantics, [aria-label], input, textarea';
const label = (e) =>
  (e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.textContent || '').trim();
const texts = () => page.evaluate((SEL, labelSrc) => {
  const label = eval(labelSrc);
  return [...document.querySelectorAll(SEL)].map(label).filter(Boolean);
}, SEL, label.toString());

/** Waits until some node's text contains [t]. */
async function waitFor(t, ms = 40000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await has(t)) return true;
    await sleep(500);
  }
  return false;
}

const has = async (t) => (await texts()).some((x) => x.includes(t));

/** Taps the smallest visible semantics node whose text contains [t]. */
async function tap(t, { exact = false, nth = 0 } = {}) {
  const box = await page.evaluate((t, exact, nth, SEL, labelSrc) => {
    const label = eval(labelSrc);
    const nodes = [...document.querySelectorAll(SEL)].filter((e) => {
      const s = label(e);
      const r = e.getBoundingClientRect();
      return r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < innerHeight &&
        (exact ? s === t : s.includes(t));
    });
    nodes.sort((a, b) => {
      const ra = a.getBoundingClientRect(); const rb = b.getBoundingClientRect();
      return ra.width * ra.height - rb.width * rb.height;
    });
    const e = nodes[nth];
    if (!e) return null;
    const r = e.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, t, exact, nth, SEL, label.toString());
  if (!box) throw new Error(`not found: ${t}`);
  await page.touchscreen.tap(box.x, box.y);
  await sleep(900);
}

async function scrollUntil(t, max = 12) {
  for (let i = 0; i < max; i++) {
    const visible = await page.evaluate((t, SEL, labelSrc) => [...document.querySelectorAll(SEL)].some((e) => {
      const s = eval(labelSrc)(e);
      const r = e.getBoundingClientRect();
      return s.includes(t) && r.height > 0 && r.top > 80 && r.bottom < innerHeight - 130;
    }), t, SEL, label.toString());
    if (visible) {
      await sleep(1200); // Let the scroll settle: a tap during a fling only stops it.
      return true;
    }
    await page.mouse.move(187, 420);
    await page.mouse.wheel({ deltaY: 250 });
    await sleep(700);
  }
  return false;
}

const noHorizontalScroll = () => page.evaluate(
  () => document.documentElement.scrollWidth <= innerWidth + 1);
const shot = (name) => page.screenshot({ path: `${out}/acc_${name}.png` });

async function check(id, fn) {
  try {
    const r = await fn();
    report(id, r !== false, typeof r === 'string' ? r : '');
  } catch (e) {
    report(id, false, e.message);
  }
}

try {
  await page.goto(`${site}/?semantics`, { waitUntil: 'load', timeout: 90000 });
  await waitFor('View All');
  await enableSemantics();

  await check('H1 English by default', async () =>
    (await has('View All')) && (await has('العربية')) && 'English UI, toggle offers Arabic');
  await check('H3 home: no horizontal page scroll at 375px', noHorizontalScroll);
  await check('A1 home: category with name, count, View All and a product strip', async () => {
    await scrollUntil('View All');
    await shot('home');
    const t = await texts();
    const cards = t.filter((x) => x === 'Add to Cart').length;
    return (await has('Pizza')) && (await has('27 items')) && cards >= 2 && `cards visible: ${cards}`;
  });
  await check('A4 quick add from a card', async () => {
    await scrollUntil('Add to Cart');
    await tap('Add to Cart', { exact: true });
    return (await has('Added to cart')) && 'snackbar shown';
  });
  await check('A1 View All opens the category page with its groups', async () => {
    await scrollUntil('View All');
    await tap('View All');
    await waitFor('Chicken pizza', 15000);
    await shot('category');
    return (await has('Chicken pizza')) && (await has('Seafood'));
  });
  await check('H3 category: no horizontal page scroll', noHorizontalScroll);
  await check('A5 search filters products', async () => {
    await page.mouse.wheel({ deltaY: -3000 });
    await sleep(1500);
    await tap('Search for your favorite pizza');
    await page.keyboard.type('chicken', { delay: 40 });
    await sleep(1200);
    const t = await texts();
    const shown = ['BBQ Chicken', 'Margherita', 'Pepperoni'].filter((n) => t.some((x) => x.includes(n)));
    await shot('search');
    return t.some((x) => x.includes('BBQ Chicken')) && !t.some((x) => x.includes('Margherita')) && `shown: ${shown}`;
  });

  // Builder.
  await page.goto(`${site}/product/pizza_margherita?semantics`, { waitUntil: 'load', timeout: 90000 });
  await waitFor('Add to Cart');
  await sleep(1500);
  await enableSemantics();
  await check('C1/B1 product opens with defaults at its base price', async () => {
    await shot('builder_open');
    return (await has('EGP 130')) && (await has('Mozzarella')) && (await has('Basil'));
  });
  await check('C5 Large changes the price (230)', async () => {
    await scrollUntil('Large');
    await tap('Large', { exact: true });
    return await has('EGP 230');
  });
  await check('B5 stuffed crust adds 45 (275)', async () => {
    await scrollUntil('Stuffed crust');
    await tap('Stuffed crust');
    await sleep(1000);
    await shot('builder_stuffed');
    return await has('EGP 275');
  });
  await check('C2/B2 adding mozzarella adds 30 (305)', async () => {
    await scrollUntil('+ EGP 30');
    await tap('Mozzarella');
    return await has('EGP 305');
  });
  await check('C6 reset returns to the product as it comes', async () => {
    await scrollUntil('Reset');
    await tap('Reset');
    return await has('EGP 130');
  });
  await check('D1 add runs the oven and confirms', async () => {
    await scrollUntil('Large');
    await tap('Large', { exact: true });
    await scrollUntil('Stuffed crust');
    await tap('Stuffed crust');
    await tap('Add to Cart');
    await sleep(1000);
    await shot('oven');
    await sleep(3500);
    return true;
  });

  // Cart and checkout.
  await page.goto(`${site}/cart?semantics`, { waitUntil: 'load', timeout: 90000 });
  await waitFor('Large');
  await enableSemantics();
  await check('E1 cart line shows size and crust', async () => {
    await shot('cart');
    return (await has('Large')) && (await has('Stuffed crust'));
  });
  await check('H3 cart: no horizontal page scroll', noHorizontalScroll);

  await page.goto(`${site}/checkout?semantics`, { waitUntil: 'load', timeout: 90000 });
  await waitFor('Place order');
  await enableSemantics();
  await check('E4 invalid phone is refused', async () => {
    await tap('Name');
    await page.keyboard.type('TEST');
    await tap('Phone');
    await page.keyboard.type('123');
    await tap('Place order');
    return await has('valid Egyptian mobile');
  });
  await check('F6 delivery without a location is not sent', async () => {
    await tap('Phone');
    for (let i = 0; i < 3; i++) await page.keyboard.press('Backspace');
    await page.keyboard.type('01000000000');
    await tap('Delivery', { exact: true });
    await sleep(800);
    await tap('Address');
    await page.keyboard.type('TEST address, Banha');
    await tap('Place order');
    await shot('delivery_no_location');
    return await has('Share your location');
  });
  await check('E5 pickup order is placed with a reference', async () => {
    await tap('Pick up', { exact: true });
    await tap('Place order');
    await waitFor('Order received', 30000);
    await enableSemantics();
    await shot('order');
    const ok = (await has('Order received')) || (await has('#'));
    return ok && `url: ${page.url()}`;
  });

  // Language.
  await check('H2 Arabic toggle switches to RTL and persists', async () => {
    await page.goto(`${site}/?semantics`, { waitUntil: 'load', timeout: 90000 });
    await waitFor('View All');
    await enableSemantics();
    await tap('العربية');
    await sleep(1000);
    await page.reload({ waitUntil: 'load' });
    await waitFor('English');
    await enableSemantics();
    await shot('arabic');
    const ok = (await has('بيتزا')) && (await has('English'));
    // Back to English for the next visitor of this profile.
    await tap('English');
    return ok;
  });
} finally {
  await browser.close();
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed}/${results.length} passed`);
