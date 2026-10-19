// Zorunlu güncelleme ayarı (20261019160000_app_config): herkes okur,
// kimse uygulamadan değiştiremez; geri alma.
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

const rows = async () => (await db.query(`select min_build, update_url from public.app_config`)).rows;
let r = await rows();
check(r.length === 1 && r[0].min_build === 1 && r[0].update_url === null, 'tek satır, varsayılan hiçbir sürümü kilitlemez', r);

for (const role of ['anon', 'authenticated']) {
  await db.exec(`set role ${role}`);
  check((await rows()).length === 1, `${role} okuyabilir (girişten önce de)`);
  await expectError(`${role} değiştiremez`, () => db.exec(`update public.app_config set min_build = 99`));
  await expectError(`${role} satır ekleyemez`, () => db.exec(`insert into public.app_config (id) values (true)`));
  await db.exec('reset role');
}
await expectError('ikinci satır olamaz', () => db.exec(`insert into public.app_config (id) values (false)`));
await expectError('adres https olmalı', () => db.exec(`update public.app_config set update_url = 'http://x.com'`));
await db.exec(`update public.app_config set min_build = 3, update_url = 'https://example.com/mentoria.apk'`);
r = await rows();
check(r[0].min_build === 3, 'platform yöneticisi SQL ile değiştirir');

const name = '20261019160000_app_config';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await db.query(`select to_regclass('public.app_config') t`)).rows[0].t === null, 'geri alındı');
await db.exec(read(migDir, `${name}.sql`));
check((await rows()).length === 1, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
