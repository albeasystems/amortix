// Happy path of Amortix as a looping GIF + animated WebP, in two looks:
//   gif/amortix-<lang>-framed.gif   phone bezel + caption, for social, README, App Store product page
//   gif/amortix-<lang>-screen.{gif,webp}   the bare screen, so the web can wrap it in CSS
// Run: npm install && node make-gif.mjs   (needs source/<lang>/<step>.png, taken in the iOS Simulator)
import sharp from 'sharp';
import pkg from 'gifenc';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const { GIFEncoder, quantize, applyPalette } = pkg;

const root = path.dirname(fileURLToPath(import.meta.url));
const SCREEN_W = 590;
const SCREEN_H = Math.round(SCREEN_W * 2868 / 1320);
const BLUE = '#2269de';

const STEPS = [
  ['01-inputs', 1900], ['02-advanced', 2500], ['03-results', 2500], ['04-chart', 2500], ['05-table', 2800],
];
// Captions and the OG headline come from the site's own copy, so the media speaks every language of the app.
const WEB = path.join(root, '..', 'web');
const content = {};
for (const l of ['es', 'en', 'fr', 'it', 'de', 'pt', 'ar', 'hi', 'zh']) content[l] = (await import(path.join(WEB, 'src', 'content', `${l}.js`))).default;
const CAPTIONS = Object.fromEntries(Object.entries(content).map(([l, c]) => [l, c.home.app.views.map((v) => v.caption)]));
const LANGS = Object.keys(CAPTIONS).filter((l) => fs.existsSync(path.join(root, 'source', l, '01-inputs.png')));
const OUT = path.join(WEB, 'public', 'media');
fs.mkdirSync(path.join(OUT, 'views'), { recursive: true });

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');

async function framed(screenPng, caption, idx, total) {
  const W = 720, H = 1560, padX = 62, top = 235, bez = 12;
  const pw = W - padX * 2, ph = Math.round(pw * 2868 / 1320);
  const screen = await sharp(screenPng).resize({ width: pw - bez * 2 }).toBuffer();
  const sh = (await sharp(screen).metadata()).height;
  const r = 78, ri = r - bez;
  const mask = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${pw - bez * 2}" height="${sh}"><rect width="100%" height="100%" rx="${ri}" fill="#fff"/></svg>`);
  const rounded = await sharp(screen).composite([{ input: mask, blend: 'dest-in' }]).png().toBuffer();
  const dots = Array.from({ length: total }, (_, i) => `<circle cx="${W / 2 - (total - 1) * 14 + i * 28}" cy="150" r="${i === idx ? 6 : 4}" fill="${i === idx ? '#6fa0ff' : '#3a3d44'}"/>`).join('');
  const bg = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
    <rect width="100%" height="100%" fill="#0b0f17"/>
    <text x="${W / 2}" y="105" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-weight="700" font-size="44" fill="#edf1f7" letter-spacing="-1">${esc(caption)}</text>
    ${dots}
    <rect x="${padX}" y="${top}" width="${pw}" height="${ph}" rx="${r}" fill="#050505" stroke="#ffffff" stroke-opacity=".16" stroke-width="2"/>
  </svg>`);
  return sharp(bg).composite([{ input: rounded, left: padX + bez, top: top + bez }]).raw().toBuffer({ resolveWithObject: true });
}

fs.mkdirSync(path.join(root, 'gif'), { recursive: true });
for (const lang of LANGS) {
  const screenGif = GIFEncoder(), framedGif = GIFEncoder();
  const webpFrames = [], delays = [];
  for (let i = 0; i < STEPS.length; i++) {
    const [name, hold] = STEPS[i];
    const src = fs.readFileSync(path.join(root, 'source', lang, `${name}.png`));
    const a = await sharp(src).resize({ width: SCREEN_W, height: SCREEN_H, fit: 'cover' }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const pa = quantize(a.data, 256, { format: 'rgb565' });
    screenGif.writeFrame(applyPalette(a.data, pa, 'rgb565'), a.info.width, a.info.height, { palette: pa, delay: hold });
    const f = await framed(src, CAPTIONS[lang][i], i, STEPS.length);
    const pf = quantize(f.data, 256, { format: 'rgb565' });
    framedGif.writeFrame(applyPalette(f.data, pf, 'rgb565'), f.info.width, f.info.height, { palette: pf, delay: hold });
    webpFrames.push(await sharp(src).resize({ width: SCREEN_W }).png().toBuffer());
    delays.push(hold);
    // single views for the site walk-through
    fs.mkdirSync(path.join(root, 'views', lang), { recursive: true });
    await sharp(src).resize({ width: 600 }).webp({ quality: 82 }).toFile(path.join(root, 'views', lang, `${name.slice(3)}.webp`));
    fs.mkdirSync(path.join(OUT, 'views', lang), { recursive: true });
    await sharp(src).resize({ width: 600 }).webp({ quality: 82 }).toFile(path.join(OUT, 'views', lang, `${name.slice(3)}.webp`));
  }
  screenGif.finish(); framedGif.finish();
  const outs = { [`amortix-${lang}-screen.gif`]: screenGif.bytes(), [`amortix-${lang}-framed.gif`]: framedGif.bytes() };
  for (const [f, bytes] of Object.entries(outs)) { fs.writeFileSync(path.join(root, 'gif', f), bytes); console.log(f, (bytes.length / 1024).toFixed(0) + ' KB'); }
  const webp = await sharp(webpFrames, { join: { animated: true } })
    .webp({ quality: 78, effort: 5, loop: 0, delay: delays }).toBuffer();
  fs.writeFileSync(path.join(root, 'gif', `amortix-${lang}-screen.webp`), webp);
  fs.writeFileSync(path.join(OUT, `amortix-${lang}-screen.webp`), webp);
  fs.writeFileSync(path.join(OUT, `amortix-${lang}-framed.gif`), framedGif.bytes());
  await og(lang);
  console.log(`amortix-${lang}-screen.webp`, (webp.length / 1024).toFixed(0) + ' KB');
}

// 1200x630 social card: the headline on the left, the chart capture on the right.
async function og(lang) {
  const c = content[lang], rtl = lang === 'ar', cjk = lang === 'zh' || lang === 'hi' || lang === 'ar';
  const max = lang === 'zh' ? 11 : cjk ? 20 : 24;
  const words = c.home.h1.split(lang === 'zh' ? '' : ' ');
  const lines = []; let cur = '';
  for (const w of words) { const t = cur ? (lang === 'zh' ? cur + w : `${cur} ${w}`) : w; if (t.length > max && cur) { lines.push(cur); cur = w; } else cur = t; }
  if (cur) lines.push(cur);
  const size = lines.length > 4 ? 54 : 62, x = rtl ? 640 : 70, anchor = rtl ? 'end' : 'start';
  const font = 'Helvetica Neue, Arial, PingFang SC, Geeza Pro, Kohinoor Devanagari, sans-serif';
  const text = lines.map((l, i) => `<text x="${x}" y="${210 + i * (size + 10)}" font-family="${font}" font-size="${size}" font-weight="700" fill="#0e1726" text-anchor="${anchor}" ${rtl ? 'direction="rtl"' : ''}>${esc(l)}</text>`).join('');
  const shot = await sharp(path.join(root, 'source', lang, '04-chart.png')).resize({ width: 360 }).extract({ left: 0, top: 230, width: 360, height: 500 }).toBuffer();
  const sm = await sharp(shot).metadata();
  const mask = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${sm.width}" height="${sm.height}"><rect width="100%" height="${sm.height + 60}" rx="34" fill="#fff"/></svg>`);
  const rounded = await sharp(shot).composite([{ input: mask, blend: 'dest-in' }]).png().toBuffer();
  const px = rtl ? 70 : 1200 - 70 - sm.width, py = 130;
  const bg = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630"><rect width="1200" height="630" fill="#fbfbfc"/>
    <rect x="${px - 8}" y="${py - 8}" width="${sm.width + 16}" height="${sm.height + 80}" rx="42" fill="#fff" stroke="#c5ccd8" stroke-width="2"/>
    ${text}
    <text x="${x}" y="570" font-family="${font}" font-size="30" font-weight="700" fill="#2269de" text-anchor="${anchor}" ${rtl ? 'direction="rtl"' : ''}>Amortix</text></svg>`);
  const out = await sharp(bg).composite([{ input: rounded, left: px, top: py }]).jpeg({ quality: 86 }).toBuffer();
  fs.writeFileSync(path.join(OUT, `og-${lang}.jpg`), out);
  console.log(`og-${lang}.jpg`);
}
