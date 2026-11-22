// Debug helper: CPU profile of the warm add animation on a product page,
// printed as the functions with the most self time (use a --profile build
// for readable names). Same emulation as measure.mjs.
//   SITE=http://localhost:8080 node profile_add.mjs /product/crepe_fruit
import puppeteer from 'puppeteer-core';

const site = process.env.SITE ?? 'https://menova-80602.web.app';
const path = process.argv[2] ?? '/product/crepe_fruit';
const cpu = Number(process.env.CPU ?? 4);
const chrome =
  process.env.CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: true,
  args: process.env.GPU === 'soft'
    ? ['--disable-gpu', '--enable-unsafe-swiftshader']
    : ['--enable-gpu-rasterization', '--ignore-gpu-blocklist'],
});
try {
  const page = await browser.newPage();
  await page.emulate({
    viewport: { width: 375, height: 812, deviceScaleFactor: Number(process.env.DPR ?? 2), isMobile: true, hasTouch: true },
    userAgent: 'Mozilla/5.0 (Linux; Android 13; Pixel 6a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
  });
  const cdp = await page.createCDPSession();
  await page.goto(`${site}${path}`, { waitUntil: 'networkidle0', timeout: 90000 });
  await sleep(4000);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
  // A cold add first, so the profile is the steady state.
  await page.touchscreen.tap(187, 773);
  await sleep(5000);
  await cdp.send('Profiler.enable');
  await cdp.send('Profiler.setSamplingInterval', { interval: 200 });
  await cdp.send('Profiler.start');
  await page.touchscreen.tap(187, 773);
  await sleep(5000);
  const { profile } = await cdp.send('Profiler.stop');
  const self = new Map();
  const dt = profile.timeDeltas;
  const byId = new Map(profile.nodes.map((n) => [n.id, n]));
  profile.samples.forEach((id, i) => {
    const n = byId.get(id);
    const k = `${n.callFrame.functionName || '(anon)'} ${n.callFrame.url.split('/').pop()}`;
    self.set(k, (self.get(k) ?? 0) + (dt[i] ?? 0) / 1000);
  });
  const total = [...self.values()].reduce((a, b) => a + b, 0);
  console.log(`total ${total.toFixed(0)} ms`);
  const byFile = new Map();
  for (const [k, v] of self) {
    const f = k.split(' ').pop() || '(native)';
    byFile.set(f, (byFile.get(f) ?? 0) + v);
  }
  console.log([...byFile].sort((a, b) => b[1] - a[1]).slice(0, 6)
    .map(([f, v]) => `${f}=${v.toFixed(0)}`).join('  '));
  // Inclusive time of the frame phases (a profile build keeps their names).
  const parent = new Map();
  for (const n of profile.nodes) for (const c of n.children ?? []) parent.set(c, n.id);
  const incl = new Map();
  const want = /^(buildScope|flushLayout|flushPaint|compositeFrame|render|rasterize|toImageSync|drawFrame|handleDrawFrame|handleBeginFrame|_rasterize|draw|submit|flushCompositingBits|preroll|paint)\$/;
  profile.samples.forEach((id, i) => {
    const seen = new Set();
    for (let x = id; x != null; x = parent.get(x)) {
      const f = byId.get(x).callFrame.functionName.split('$')[0] + '$';
      if (want.test(f) && !seen.has(f)) {
        seen.add(f);
        incl.set(f, (incl.get(f) ?? 0) + (dt[i] ?? 0) / 1000);
      }
    }
  });
  console.log('inclusive:', [...incl].sort((a, b) => b[1] - a[1])
    .map(([f, v]) => `${f}=${v.toFixed(0)}`).join('  '));
  for (const [k, v] of [...self.entries()].sort((a, b) => b[1] - a[1]).slice(0, 40)) {
    console.log(`${v.toFixed(0).padStart(6)} ms  ${k}`);
  }
} finally {
  await browser.close();
}
