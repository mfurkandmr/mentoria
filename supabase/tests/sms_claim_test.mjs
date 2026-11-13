// SMS kuyruğu: claim_sms aynı mesajı ikinci kez vermez
// (20261110100000_sms_claim).
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';

const root = process.argv[2] ?? '../..';
const migDir = `${root}/supabase/migrations`;
const rbDir = `${root}/supabase/rollbacks`;
const migs = fs.readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort();
const read = (d, f) => fs.readFileSync(`${d}/${f}`, 'utf8');
const seed = read(`${root}/supabase`, 'seed.sql') + '\n' + read(`${root}/supabase`, 'seed_ayt_ydt_topics.sql');

const db = new PGlite();
let failures = 0;
const ok = (n) => console.log('  PASS', n);
const bad = (n, i) => { failures++; console.log('  FAIL', n, i === undefined ? '' : JSON.stringify(i)); };
const check = (c, n, i) => (c ? ok(n) : bad(n, i));

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
await db.exec(seed);
ok(`${migs.length} migration + seed`);

const one = async (sql, p = []) => (await db.query(sql, p)).rows[0];
const rows = async (sql, p = []) => (await db.query(sql, p)).rows;

console.log('Kuyruktan alma');
const org = (await one(`insert into public.organizations (name, seat_limit) values ('SMS Kurumu', 20) returning id, tenant_id`));
for (const n of [1, 2, 3]) {
  await db.query(
    `insert into public.sms_outbox (tenant_id, org_id, channel, phone, body, created_at)
     values ($1, $2, 'sms', '+90500000000${n}', 'mesaj ${n}', now() - make_interval(mins => $3))`,
    [org.tenant_id, org.id, 10 - n]);
}
const first = await rows(`select * from public.claim_sms(2)`);
check(first.length === 2 && first[0].body === 'mesaj 1' && first[1].body === 'mesaj 2',
  'ilk çağrı en eski 2 mesajı alır', first);
check((await one(`select count(*)::int c from public.sms_outbox where status = 'sending'`)).c === 2,
  "alınanlar 'sending' olur");
const second = await rows(`select * from public.claim_sms(50)`);
check(second.length === 1 && second[0].body === 'mesaj 3', 'ikinci çağrı yalnızca kalan mesajı alır', second);
check((await rows(`select * from public.claim_sms(50)`)).length === 0, 'üçüncü çağrı boş döner (çift gönderim yok)');

console.log('Yarıda kalan gönderim');
await db.query(`update public.sms_outbox set claimed_at = now() - interval '16 minutes' where body = 'mesaj 1'`);
await rows(`select * from public.claim_sms(50)`);
const stale = await one(`select status, error from public.sms_outbox where body = 'mesaj 1'`);
check(stale.status === 'failed' && stale.error.includes('zaman aşımı'),
  "15 dakikadan uzun 'sending' kalan 'failed' olur, yeniden gönderilmez", stale);
check((await one(`select status from public.sms_outbox where body = 'mesaj 2'`)).status === 'sending',
  'yeni alınan mesaja dokunulmaz');

console.log('Yetki');
await db.exec(`set role authenticated;`);
try {
  await db.query(`select * from public.claim_sms(50)`);
  bad('uygulama kullanıcısı claim_sms çağıramaz', 'hata bekleniyordu');
} catch (e) {
  check(e.message.includes('permission denied'), 'uygulama kullanıcısı claim_sms çağıramaz', e.message);
}
await db.exec(`reset role;`);

console.log('Geri alma ve yeniden uygulama');
await db.exec(read(rbDir, '20261110100000_sms_claim.down.sql'));
check((await one(`select to_regprocedure('public.claim_sms(int)') f`)).f === null, 'claim_sms kaldırıldı');
check((await one(`select count(*)::int c from public.sms_outbox where status = 'sending'`)).c === 0,
  "'sending' kalanlar sıraya döndü");
await db.exec(read(migDir, '20261110100000_sms_claim.sql'));
check((await one(`select to_regprocedure('public.claim_sms(int)') f`)).f !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
