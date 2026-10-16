// Güvenlik sıkılaştırması: anon tablolara erişemez, TRUNCATE yok,
// tetikleyici fonksiyonu çağrılamaz, logo yalnızca kendi Storage klasöründen,
// avatar_url yazılamaz, soru kaydı üst sınırı; geri alma / yeniden uygulama.
// yetki ve dershane sınırları, geri alma.
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

const asSuper = () => db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
const asUser = (id) => db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
const asAnon = () => db.exec(`set role anon; select set_config('request.jwt.claim.sub', '', false);`);
const one = async (sql, p = []) => (await db.query(sql, p)).rows[0];
async function signUp(code, name) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true })])).id;
}
async function expectError(n, fn, pattern) {
  try { await fn(); bad(n, 'hata bekleniyordu'); }
  catch (e) { (!pattern || e.message.includes(pattern)) ? ok(n) : bad(n, e.message); }
}
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id, tenant_id`, [name]));
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org.id]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const student = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, `${name} Öğrenci`);
  return { org: org.id, tenant: org.tenant_id, admin, coach, student };
}


const A = await school('Bal Akademi', 'ADMINSC1');
const B = await school('Yıldız Dershanesi', 'ADMINSC2');
const base = `https://proje.supabase.co/storage/v1/object/public/tenant-logos`;

console.log('Giriş yapmamış istemci');
await asAnon();
for (const table of ['profiles', 'subjects', 'tenants', 'invite_codes', 'exams', 'notifications']) {
  await expectError(`anon ${table} okuyamaz`, () => db.query(`select * from public.${table} limit 1`), 'permission denied');
}
await expectError('anon profil ekleyemez', () => db.query(`insert into public.profiles (id, full_name, role) values (gen_random_uuid(), 'Sahte', 'admin')`), 'permission denied');
await asSuper();
const code = (await one(`select code from public.invite_codes where expires_at > now() and used_count < max_uses limit 1`)).code;
await asAnon();
check((await one(`select public.check_invite($1) i`, [code])).i?.org_name, 'anon davet kodunu doğrulayabilir');
check((await db.query(`select public.tenant_branding('bal-akademi') b`)).rows.length === 1, 'anon dershane markasını okuyabilir');

console.log('Giriş yapmış istemci');
await asUser(A.student);
await expectError('öğrenci TRUNCATE yapamaz', () => db.query(`truncate public.question_logs`), 'permission denied');
await expectError('tetikleyici fonksiyonu çağrılamaz', () => db.query(`select public.handle_user_email_confirmed()`));
await expectError('logo yardımcı fonksiyonu çağrılamaz', () => db.query(`select public.logo_url_allowed('x', gen_random_uuid())`), 'permission denied');
await expectError('avatar_url yazılamaz', () => db.query(`update public.profiles set avatar_url = 'https://izleyici.site/p.gif' where id = $1`, [A.student]), 'permission denied');
await db.query(`update public.profiles set full_name = 'Elif Yılmaz' where id = $1`, [A.student]);
ok('öğrenci adını yine değiştirebilir');

const mat = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
await db.query(`insert into public.question_logs (student_id, subject_id, correct, wrong, blank) values ($1, $2, 900, 400, 200)`, [A.student, mat]);
ok('1.500 soruluk kayıt girilir');
await expectError('1.500 üstü soru kaydı reddedilir', () => db.query(`insert into public.question_logs (student_id, subject_id, correct) values ($1, $2, 1000000)`, [A.student, mat]), 'question_logs_total_check');

console.log('Logo adresi');
await asUser(A.admin);
const brand = (url) => db.query(`select public.update_my_branding('Bal Akademi', '#0EA5E9', '#E5484D', $1)`, [url]);
await brand(`${base}/${A.tenant}/logo-1.png`);
ok('kendi klasöründeki logo kabul edilir');
await brand(null);
ok('logo kaldırılabilir');
for (const [name, url] of [
  ['başka sunucuda aynı yol', `https://kotu.site/x/storage/v1/object/public/tenant-logos/${A.tenant}/logo.png`],
  ['supabase.co taklidi alan adı', `https://proje.supabase.co.kotu.site/storage/v1/object/public/tenant-logos/${A.tenant}/logo.png`],
  ['http (şifresiz)', `http://proje.supabase.co/storage/v1/object/public/tenant-logos/${A.tenant}/logo.png`],
  ['başka dershanenin klasörü', `${base}/${B.tenant}/logo.png`],
  ['alt klasörle kaçış', `${base}/${A.tenant}/../${B.tenant}/logo.png`],
  ['sorgu dizesi', `${base}/${A.tenant}/logo.png?x=1`],
]) {
  await expectError(`${name} reddedilir`, () => brand(url), 'LOGO_NOT_ALLOWED');
}
await asSuper();
await expectError('tabloya doğrudan yazılan dış logo da reddedilir', () => db.query(`update public.tenants set logo_url = 'https://kotu.site/logo.png' where id = $1`, [A.tenant]), 'tenants_logo_url_check');

console.log('Vault: başka bir Supabase projesinin Storage\'ı');
await db.exec(`create schema if not exists vault; create table vault.decrypted_secrets (name text, decrypted_secret text);
  insert into vault.decrypted_secrets values ('push_function_url', 'https://proje.supabase.co/functions/v1/send-push');`);
await asUser(A.admin);
await brand(`${base}/${A.tenant}/logo-2.png`);
ok('bu projenin Storage\'ı kabul edilir');
await expectError('başka Supabase projesi reddedilir', () => brand(`https://baska.supabase.co/storage/v1/object/public/tenant-logos/${A.tenant}/logo.png`), 'LOGO_NOT_ALLOWED');
await asSuper();
await db.exec(`drop schema vault cascade`);

console.log('Geri alma ve yeniden uygulama');
const name = '20261018180000_security_hardening';
await db.exec(read(rbDir, `${name}.down.sql`));
await asAnon();
check((await db.query(`select * from public.subjects`)).rows.length === 0, 'geri alınınca anon yine izinli ama RLS satır göstermez');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
await asAnon();
await expectError('yeniden uygulanınca anon yine erişemez', () => db.query(`select * from public.subjects`), 'permission denied');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
