// Web hata kaydı (20261107100000_client_errors): herkes yalnızca RPC ile
// yazar, aynı hata sayacı artırır, adres kısaltılır, yalnızca süper admin
// okur/siler; geri alma.
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';

const root = process.argv[2] ?? '../..';
const migDir = `${root}/supabase/migrations`;
const rbDir = `${root}/supabase/rollbacks`;
const migs = fs.readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort();
const read = (d, f) => fs.readFileSync(`${d}/${f}`, 'utf8');

const db = new PGlite();
let failures = 0;
const ok = (n) => console.log('  PASS', n);
const bad = (n, i) => { failures++; console.log('  FAIL', n, i === undefined ? '' : JSON.stringify(i)); };
const check = (c, n, i) => (c ? ok(n) : bad(n, i));
async function expectError(n, fn) {
  try { await fn(); bad(n, 'hata bekleniyordu'); } catch { ok(n); }
}

await db.exec(`
  create role anon nologin; create role authenticated nologin;
  create schema auth;
  grant usage on schema auth to anon, authenticated;
  create table auth.users (id uuid primary key default gen_random_uuid(), email text, raw_user_meta_data jsonb, email_confirmed_at timestamptz default now());
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema public to anon, authenticated;
  alter default privileges in schema public grant all on tables to anon, authenticated;
  alter default privileges in schema public grant all on functions to anon, authenticated;
`);
for (const f of migs) await db.exec(read(migDir, f));
ok(`${migs.length} migration`);

// Kayıt tetikleyicisi davet ister; bu test yalnızca kullanıcı kimliği istiyor.
await db.exec('alter table auth.users disable trigger user');
const admin = (await db.query(`insert into auth.users (email) values ('admin@x.tr') returning id`)).rows[0].id;
const user = (await db.query(`insert into auth.users (email) values ('ogr@x.tr') returning id`)).rows[0].id;
await db.query(`insert into public.platform_admins (user_id) values ($1)`, [admin]);

const as = async (role, uid) => {
  await db.exec('reset role');
  await db.exec(`select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`);
  await db.exec(`set role ${role}`);
};
const report = (msg, stack = 'at main.dart.js:1:2', path = '/app/student?code=SECRET#x', ver = '0.2.0+2') =>
  db.query(`select public.report_client_error($1, $2, $3, 'web', $4, 'Mozilla/5.0')`, [msg, stack, path, ver]);

// Giriş yapmamış ziyaretçi (giriş ekranı) yazabilir.
await as('anon');
await report('TypeError: null check 12');
await report('TypeError: null check 34'); // sayılar farklı: aynı hata
await expectError('anon tabloyu okuyamaz', () => db.query(`select * from public.client_errors`));
await expectError('anon doğrudan yazamaz', () => db.query(
  `insert into public.client_errors (fingerprint, app_version, platform, message) values ('x','y','web','z')`));

// Sıradan kullanıcı yazar ama okuyamaz / silemez.
await as('authenticated', user);
await report('RangeError: index 3', 'at a.js:9:9');
check((await db.query(`select * from public.client_errors`)).rows.length === 0, 'kullanıcı kayıtları göremez');
await db.query(`delete from public.client_errors`);
await db.query(`select public.report_client_error('x', null, null, 'desktop', '1', null)`);

// Süper admin okur.
await as('authenticated', admin);
let rows = (await db.query(`select * from public.client_errors order by id`)).rows;
check(rows.length === 2, 'iki ayrı hata (aynısı birleşti, kullanıcının silmesi ve geçersiz platform işe yaramadı)', rows.length);
check(rows[0].count === 2, 'aynı hata sayacı artırdı', rows[0].count);
check(rows[0].url_path === '/app/student', 'adresin sorgu ve # kısmı atıldı', rows[0].url_path);
check(!('user_id' in rows[0]) && !('email' in rows[0]), 'kimlik sütunu yok');

// Yeni sürümde aynı hata ayrı satır.
await report('TypeError: null check 12', 'at main.dart.js:1:2', '/app', '0.2.1+3');
rows = (await db.query(`select * from public.client_errors`)).rows;
check(rows.length === 3, 'yeni sürümde ayrı satır', rows.length);

// Uzun metin kesilir.
await report('x'.repeat(5000), 'y'.repeat(20000));
const long = (await db.query(`select length(message) m, length(stack) s from public.client_errors order by id desc limit 1`)).rows[0];
check(long.m === 1000 && long.s === 8000, 'mesaj ve yığın kısaltıldı', long);

// Süper admin silebilir.
await db.query(`delete from public.client_errors where app_version = '0.2.1+3'`);
check((await db.query(`select * from public.client_errors`)).rows.length === 3, 'süper admin sildi');

// Taşma koruması: son saatte 500 yeni satır varsa yenisi açılmaz.
await db.exec('reset role');
await db.exec(`insert into public.client_errors (fingerprint, app_version, platform, message)
  select 'fp' || g, 'flood', 'web', 'm' from generate_series(1, 500) g`);
await as('anon');
await report('Yepyeni hata', 'at z.js:1:1', '/app', 'flood2');
await db.exec('reset role');
check((await db.query(`select * from public.client_errors where app_version = 'flood2'`)).rows.length === 0,
  'saatte 500 sınırı aşılınca yeni satır açılmaz');

// Geri alma ve yeniden uygulama.
const name = '20261107100000_client_errors';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await db.query(`select to_regclass('public.client_errors') t`)).rows[0].t === null, 'geri alındı');
await db.exec(read(migDir, `${name}.sql`));
check((await db.query(`select to_regclass('public.client_errors') t`)).rows[0].t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
