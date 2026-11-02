// KVKK saklama görevleri (20261029100000_retention_jobs): eski duyurular,
// lisansı biten kurum, uzun süre kullanılmayan hesap (uyarı + silme).
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

// Gerçek Supabase'deki gibi: kayıt / son giriş zamanı ve oturum yenileme kayıtları.
await db.exec(`
  create role anon nologin; create role authenticated nologin;
  create schema auth;
  grant usage on schema auth to anon, authenticated;
  create table auth.users (id uuid primary key default gen_random_uuid(), email text, raw_user_meta_data jsonb,
    email_confirmed_at timestamptz default now(), created_at timestamptz default now(), last_sign_in_at timestamptz);
  create table auth.refresh_tokens (id bigserial primary key, user_id varchar(255), updated_at timestamp);
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
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  return { org, admin: await signUp(code, `${name} Müdür`) };
}
async function coachIn(admin, name) {
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, name);
  await asUser(coach);
  return { id: coach, code: (await one(`select public.create_invite('student', null, 10) c`)).c };
}
const exists = async (id) => { await asSuper(); return !!(await one(`select 1 x from public.profiles where id = $1`, [id])); };
const warnings = async (id) => {
  await asSuper();
  return Number((await one(`select count(*) n from public.notifications where user_id = $1 and kind = 'inactivity_warning'`, [id])).n);
};
const inactive = async () => { await asSuper(); return (await one(`select public.process_inactive_accounts() r`)).r; };
// Son etkinliği geriye al: kayıt ve son giriş zamanı.
const idleFor = async (id, interval) => {
  await asSuper();
  await db.query(`update auth.users set created_at = now() - $2::interval, last_sign_in_at = now() - $2::interval where id = $1`, [id, interval]);
};

const a = await school('Anka', 'ANKA-ADMIN');
const anka = await coachIn(a.admin, 'Anka Koç');
const ankaStudent = await signUp(anka.code, 'Anka Öğrenci');

const b = await school('Bulut', 'BULUT-ADMIN');
const bulut = await coachIn(b.admin, 'Bulut Koç');
const ali = await signUp(bulut.code, 'Ali');
const ayse = await signUp(bulut.code, 'Ayşe');
const can = await signUp(bulut.code, 'Can');
const lonelyCoach = (await coachIn(b.admin, 'Öğrencisiz Koç')).id;

// --- Yetki ----------------------------------------------------------------------
await asUser(ali);
await expectError('öğrenci gece görevini çalıştıramaz', () => db.query(`select public.run_retention_jobs()`), 'permission');
await expectError('öğrenci süreleri okuyamaz', () => db.query(`select * from public.retention_settings`), 'permission');
await expectError('öğrenci uyarı kayıtlarını okuyamaz', () => db.query(`select * from public.inactivity_warnings`), 'permission');
await asSuper();
await expectError('süre 180 günden kısa olamaz', () => db.exec(`update public.retention_settings set inactive_after = '30 days'`));

// --- 1. Eski duyurular -------------------------------------------------------------
await asUser(b.admin);
const oldAnn = (await one(`select public.send_announcement('students', 'Eski duyuru', 'Geçen yılın duyurusu') n`)).n;
const newAnn = (await one(`select public.send_announcement('students', 'Yeni duyuru', 'Bu haftanın duyurusu') n`)).n;
check(oldAnn === 3 && newAnn === 3, 'iki duyuru üçer öğrenciye gitti', { oldAnn, newAnn });
await asSuper();
const oldId = (await one(`select id from public.announcements where title = 'Eski duyuru'`)).id;
await db.query(`update public.announcements set created_at = now() - interval '13 months' where id = $1`, [oldId]);
check((await one(`select public.purge_old_announcements() n`)).n === 1, '1 yıldan eski duyuru silindi');
check(!(await one(`select 1 x from public.announcements where id = $1`, [oldId])), 'eski duyuru yok');
check(Number((await one(`select count(*) n from public.notifications where kind = 'announcement' and ref_id = $1`, [oldId])).n) === 0,
  'eski duyurunun bildirimleri de silindi');
check(Number((await one(`select count(*) n from public.notifications where kind = 'announcement'`)).n) === 3,
  'yeni duyurunun bildirimleri duruyor');

// --- 2. Lisansı biten kurum ---------------------------------------------------------
await db.query(`update public.organizations set license_expires_at = now() - interval '100 days' where id = $1`, [a.org]);
check((await one(`select public.purge_expired_organizations() n`)).n === 0, 'lisans 1 yıldan kısa süre önce bittiyse silinmez');
await db.query(`update public.organizations set license_expires_at = now() - interval '400 days' where id = $1`, [a.org]);
check((await one(`select public.purge_expired_organizations() n`)).n === 3, 'lisansı 1 yıldan önce biten kurumun 3 hesabı silindi');
check(!(await exists(ankaStudent)) && !(await exists(anka.id)) && !(await exists(a.admin)), 'Anka hesapları yok');
check(await exists(ali) && await exists(b.admin), 'başka kurum etkilenmedi');

// --- 3. Uzun süre kullanılmayan hesaplar ---------------------------------------------
let r = await inactive();
check(r.warned === 0 && r.deleted === 0, 'yeni hesaplara dokunulmaz', r);

// Ali: 2 yıla 10 gün kala → uyarı, ama henüz silinmez.
await idleFor(ali, '720 days');
r = await inactive();
check(r.warned === 1 && r.deleted === 0 && (await warnings(ali)) === 1, 'Ali uyarıldı', r);
r = await inactive();
check(r.warned === 0 && (await warnings(ali)) === 1, 'uyarı bir kez gider', r);

// Ayşe: 3 yıl önce giriş yaptı ama uygulama oturumu dün yenilendi → etkin.
await idleFor(ayse, '3 years');
await db.query(`insert into auth.refresh_tokens (user_id, updated_at) values ($1, (now() - interval '1 day') at time zone 'UTC')`, [ayse]);
r = await inactive();
check((await warnings(ayse)) === 0, 'oturumu yenilenen hesap etkin sayılır', r);

// Ali 2 yılı geçti ama uyarının üstünden 30 gün geçmedi → silinmez.
await idleFor(ali, '800 days');
r = await inactive();
check(r.deleted === 0 && await exists(ali), 'uyarıdan 30 gün geçmeden silinmez', r);
await db.query(`update public.inactivity_warnings set warned_at = now() - interval '31 days' where user_id = $1`, [ali]);
r = await inactive();
check(r.deleted === 1 && !(await exists(ali)), 'uyarıdan 30 gün sonra hâlâ girmeyen silindi', r);

// Can uyarıldıktan sonra uygulamayı açtı → uyarı düşer, silinmez.
await idleFor(can, '800 days');
await inactive();
check((await warnings(can)) === 1, 'Can uyarıldı');
await db.query(`update public.inactivity_warnings set warned_at = now() - interval '31 days' where user_id = $1`, [can]);
await db.query(`update auth.users set last_sign_in_at = now() where id = $1`, [can]);
r = await inactive();
check(r.deleted === 0 && await exists(can), 'uyarıdan sonra giren silinmez', r);
check(!(await one(`select 1 x from public.inactivity_warnings where user_id = $1`, [can])), 'uyarı kaydı temizlendi');

// Öğrencisi olan koç ve öğrencisi olan kurumun tek müdürü silinmez; öğrencisiz koç silinir.
for (const id of [bulut.id, b.admin, lonelyCoach]) await idleFor(id, '800 days');
await inactive();
await db.exec(`update public.inactivity_warnings set warned_at = now() - interval '31 days'`);
r = await inactive();
check(await exists(bulut.id), 'öğrencisi olan koç silinmez');
check(await exists(b.admin), 'öğrencisi olan kurumun tek müdürü silinmez');
check(!(await exists(lonelyCoach)), 'öğrencisiz hareketsiz koç silindi', r);

// Platform yöneticisi hiç uyarılmaz.
await db.query(`insert into public.platform_admins (user_id) values ($1)`, [b.admin]);
await db.query(`delete from public.inactivity_warnings where user_id = $1`, [b.admin]);
await inactive();
check(!(await one(`select 1 x from public.inactivity_warnings where user_id = $1`, [b.admin])), 'platform yöneticisi uyarılmaz');

r = (await one(`select public.run_retention_jobs() r`)).r;
check(r && 'announcements' in r && 'expired_org_accounts' in r && 'inactive' in r, 'run_retention_jobs hepsini çalıştırır', r);

// --- Geri alma / yeniden uygulama ----------------------------------------------------
const name = '20261029100000_retention_jobs';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.retention_settings') t`)).t === null, 'geri alındı');
await expectError('eski bildirim türü kısıtı geri geldi',
  () => db.query(`insert into public.notifications (user_id, kind, data) values ($1, 'inactivity_warning', '{}')`, [can]));
await db.exec(read(migDir, `${name}.sql`));
check(Number((await one(`select count(*) n from public.retention_settings`)).n) === 1, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
