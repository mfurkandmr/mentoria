// Tanıtım sayfasının ekran görüntüleri: gizli demodan (örnek veri, gerçek
// kullanıcı verisi yok) başsız Chrome ile çekilir -> site/img/*.webp.
//
//   python tool/web/build_web.py --serve     (başka bir terminalde)
//   node tool/web/screenshots.mjs
//
// Chrome DevTools protokolüyle (Node 22'nin yerleşik WebSocket'i): telefon
// genişliği taklit edilir, açık tema zorlanır, kokpitin sıralı belirişi
// bitsin diye gerçek zamanla beklenir.
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const IMG = join(ROOT, 'site', 'img');
const BASE = process.env.PREVIEW_URL ?? 'http://localhost:8790';
const PORT = 9333;

// ad: [adres, genişlik, yükseklik, ölçek, telefon mu]
const SHOTS = {
  kokpit: ['/demo/panel/admin', 1440, 900, 1, false],
  koc: ['/demo/panel/coach', 1440, 900, 1, false],
  sms: ['/demo/panel/admin/sms', 390, 844, 2, true],
  trend: ['/demo/panel/admin/trends', 390, 844, 2, true],
  yoklama: ['/demo/panel/admin/attendance', 390, 844, 2, true],
  ogrenci: ['/demo/panel/student', 390, 844, 2, true],
  veli: ['/demo/panel/parent', 390, 844, 2, true],
};

const CHROMES = [
  process.env.CHROME,
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
].filter(Boolean);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitForDebugger() {
  for (let i = 0; i < 50; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json/version`);
      if (res.ok) return;
    } catch {}
    await sleep(200);
  }
  throw new Error('Chrome hata ayıklama portu açılmadı');
}

function connect(url) {
  const ws = new WebSocket(url);
  let id = 0;
  const pending = new Map();
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
    }
  };
  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const n = ++id;
      pending.set(n, { resolve, reject });
      ws.send(JSON.stringify({ id: n, method, params }));
    });
  return new Promise((resolve) => {
    ws.onopen = () => resolve({ send, close: () => ws.close() });
  });
}

async function main() {
  const exe = CHROMES.find((c) => existsSync(c));
  if (!exe) throw new Error('Chrome/Edge bulunamadı (CHROME ortam değişkeni)');
  mkdirSync(IMG, { recursive: true });
  const profile = mkdtempSync(join(tmpdir(), 'mentoria-shots-'));
  const chrome = spawn(exe, [
    '--headless=new',
    `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${profile}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--hide-scrollbars',
    'about:blank',
  ], { stdio: 'ignore' });
  try {
    await waitForDebugger();
    for (const [name, [path, w, h, scale, mobile]] of Object.entries(SHOTS)) {
      const target = await (await fetch(
        `http://127.0.0.1:${PORT}/json/new?about:blank`, { method: 'PUT' })).json();
      const cdp = await connect(target.webSocketDebuggerUrl);
      await cdp.send('Page.enable');
      await cdp.send('Emulation.setDeviceMetricsOverride', {
        width: w, height: h, deviceScaleFactor: scale, mobile,
      });
      await cdp.send('Emulation.setEmulatedMedia', {
        features: [{ name: 'prefers-color-scheme', value: 'light' }],
      });
      await cdp.send('Page.navigate', { url: BASE + path });
      await sleep(14000);
      const { data } = await cdp.send('Page.captureScreenshot', { format: 'webp', quality: 86 });
      const out = join(IMG, `${name}.webp`);
      writeFileSync(out, Buffer.from(data, 'base64'));
      console.log(out);
      cdp.close();
      await fetch(`http://127.0.0.1:${PORT}/json/close/${target.id}`);
    }
  } finally {
    chrome.kill();
    await sleep(500);
    try { rmSync(profile, { recursive: true, force: true }); } catch {}
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
