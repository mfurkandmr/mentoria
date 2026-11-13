// k6 özetinden (results/*.json) kademe ve işlem bazında tablo.
//   node report.mjs results/ramp-....json
import fs from 'node:fs';

// Verilmezse en yeni sonuç dosyası (değişme zamanına göre).
const file = process.argv[2] ?? fs.readdirSync('results')
  .filter((f) => f.endsWith('.json')).map((f) => `results/${f}`)
  .sort((a, b) => fs.statSync(a).mtimeMs - fs.statSync(b).mtimeMs).pop();
const d = JSON.parse(fs.readFileSync(file, 'utf8'));
const m = d.metrics;
const fmt = (v) => (v == null ? '-' : Math.round(v));

console.log(`# ${file}\n`);
console.log('kademe | istek/sn | işlem p50 | işlem p95 | istek p95 | istek p99 | hata %');
const rows = Object.keys(m).filter((k) => k.startsWith('action_ms{scenario:'))
  .map((k) => k.match(/scenario:r(\d+)/)[1]).map(Number).sort((a, b) => a - b);
for (const r of rows) {
  const a = m[`action_ms{scenario:r${r}}`]?.values ?? {};
  const h = m[`http_req_duration{scenario:r${r}}`]?.values ?? {};
  const f = m[`http_req_failed{scenario:r${r}}`]?.values ?? {};
  console.log(`r${r} | ${r} | ${fmt(a.med)} | ${fmt(a['p(95)'])} | ${fmt(h['p(95)'])} | ${fmt(h['p(99)'])} | ${((f.rate ?? 0) * 100).toFixed(2)}`);
}

// İşlem türüne göre (bütün kademeler): checks'ten başarı, süre için ayrı
// alt metrik yok; http_req_duration'ı action etiketine göre k6 özetlemez.
console.log('\nişlem | p50 | p95 | p99');
for (const k of Object.keys(m).filter((k) => k.startsWith('action_ms{action:')).sort()) {
  const v = m[k].values;
  console.log(`${k.match(/action:([a-z_]+)/)[1]} | ${fmt(v.med)} | ${fmt(v['p(95)'])} | ${fmt(v['p(99)'])}`);
}
const checks = d.root_group?.checks ?? [];
const fails = m.action_failed?.values?.count ?? 0;
console.log(`\nbaşarısız işlem: ${fails}; checks: ${JSON.stringify(checks.map((c) => [c.name, c.passes, c.fails]))}`);
console.log(`toplam istek: ${m.http_reqs?.values?.count}, genel istek p95: ${fmt(m.http_req_duration?.values?.['p(95)'])} ms`);
