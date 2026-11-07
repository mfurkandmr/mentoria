// Web hata kaydındaki (client_errors, NOTLAR §66) okunaksız yığını Dart
// kaynak satırlarına çevirir. Harita: aynı sürümün derlemesinden
// build/web_sourcemaps/main.dart.js.map (CI'da "web-sourcemaps-<sha>"
// artifact'ı).
//
//   node tool/web/symbolize.mjs build/web_sourcemaps/main.dart.js.map yigin.txt
//   (yığını dosya yerine standart girdiden de verebilirsin)
//
// Bağımlılık yok: kaynak haritası (v3) VLQ çözümü burada.
import { readFileSync } from 'node:fs';

const [mapPath, stackPath] = process.argv.slice(2);
if (!mapPath) {
  console.error('Kullanım: node tool/web/symbolize.mjs <main.dart.js.map> [yığın.txt]');
  process.exit(2);
}
const map = JSON.parse(readFileSync(mapPath, 'utf8'));
const stack = readFileSync(stackPath ?? 0, 'utf8');

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const val = Object.fromEntries([...B64].map((c, i) => [c, i]));

function decodeVlq(str) {
  const out = [];
  let shift = 0;
  let value = 0;
  for (const ch of str) {
    const d = val[ch];
    value += (d & 31) << shift;
    if (d & 32) {
      shift += 5;
    } else {
      out.push(value & 1 ? -(value >>> 1) : value >>> 1);
      shift = 0;
      value = 0;
    }
  }
  return out;
}

// Satır başına [üretilen sütun, kaynak, kaynak satırı, kaynak sütunu, ad].
const lines = [];
let src = 0, srcLine = 0, srcCol = 0, name = 0;
for (const lineStr of map.mappings.split(';')) {
  const segs = [];
  let genCol = 0;
  if (lineStr) {
    for (const segStr of lineStr.split(',')) {
      const s = decodeVlq(segStr);
      genCol += s[0];
      if (s.length >= 4) {
        src += s[1]; srcLine += s[2]; srcCol += s[3];
        if (s.length >= 5) name += s[4];
        segs.push([genCol, src, srcLine, srcCol, s.length >= 5 ? name : -1]);
      }
    }
  }
  lines.push(segs);
}

function lookup(line, col) {
  const segs = lines[line - 1];
  if (!segs?.length) return null;
  let best = null;
  for (const s of segs) {
    if (s[0] <= col - 1) best = s; else break;
  }
  if (!best) return null;
  const file = map.sources[best[1]] ?? '?';
  const fn = best[4] >= 0 ? map.names[best[4]] : '';
  return `${file}:${best[2] + 1}:${best[3] + 1}${fn ? ` (${fn})` : ''}`;
}

const re = /main\.dart\.js:(\d+):(\d+)/g;
for (const raw of stack.split(/\r?\n/)) {
  const hits = [...raw.matchAll(re)].map((m) => lookup(+m[1], +m[2])).filter(Boolean);
  console.log(hits.length ? `${raw.trim()}\n    → ${hits.join(' | ')}` : raw);
}
