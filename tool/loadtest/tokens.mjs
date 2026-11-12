// Test hesaplarıyla oturum açıp users.json'a erişim anahtarlarını yazar.
// Auth oturum açma sınırı (IP başına 5 dakikada ~30) yüzünden 28 hesap:
// 24 öğrenci, 3 koç, 1 müdür. Ölçülen şey istek yükü olduğu için yeterli.
// Anahtarlar ~1 saat geçerli: her test turundan önce yeniden çalıştır.
import fs from 'node:fs';
import { readEnv } from './db.mjs';

const env = readEnv();
const url = env.LT_SUPABASE_URL ?? 'https://iruiyvfndxhkuiwbekuf.supabase.co';
const key = env.LT_ANON_KEY;
const pw = env.LT_PASSWORD;
if (!key || !pw) throw new Error('.env.local: LT_ANON_KEY ve LT_PASSWORD gerekli');
if (!url.includes('iruiyvfndxhkuiwbekuf')) throw new Error('Yalnızca Mentoria-Test');

const who = [
  ...Array.from({ length: 24 }, (_, i) => [`yuk-ogr-${i + 1}@example.com`, 'student']),
  ['yuk-koc@example.com', 'coach'],
  ['yuk-koc-2@example.com', 'coach'],
  ['yuk-koc-3@example.com', 'coach'],
  ['yuk-admin@example.com', 'admin'],
];

const out = [];
for (const [email, role] of who) {
  const r = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: key, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: pw }),
  });
  const j = await r.json();
  if (!r.ok) {
    console.error(email, r.status, j.error_description ?? j.msg ?? j);
    continue;
  }
  out.push({ id: j.user.id, role, token: j.access_token });
}
fs.writeFileSync(new URL('./users.json', import.meta.url), JSON.stringify(out));
console.log(`${out.length} anahtar users.json'a yazıldı`, Object.groupBy(out, (u) => u.role) &&
  Object.fromEntries(Object.entries(Object.groupBy(out, (u) => u.role)).map(([k, v]) => [k, v.length])));
