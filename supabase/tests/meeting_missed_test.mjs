// Görüşmeye gelmeyen öğrenci (20261112110000_meeting_missed_whatsapp): koç
// işaretleyince veliye bir kez WhatsApp mesajı sıraya alınır.
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
const count = async (sql, p = []) => (await one(sql, p)).c;
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
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  return { admin, coach, org, code: (await one(`select public.create_invite('student', null, 10) c`)).c };
}


const A = await school('Bal Akademi', 'ADMINMW1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');
await asSuper();
await db.query(`insert into public.student_guardian_phones (student_id, tenant_id, guardian_name, phone)
  select id, tenant_id, 'Fatma Demir', '+905321112233' from public.profiles where id = $1`, [ahmet]);
const today = (await one(`select (now() at time zone 'Europe/Istanbul')::date::text d`)).d;
const tr = today.split('-').reverse().join('.');
const outbox = async () => (await db.query(`select phone, body, student_id, created_by, channel, template from public.sms_outbox order by created_at`)).rows;

await asUser(A.coach);
const s1 = (await one(`insert into public.meeting_schedules (coach_id, student_id, first_date, start_time, repeat_weekly)
  values ($1, $2, $3, '11:00', false) returning id`, [A.coach, ahmet, today])).id;
const s2 = (await one(`insert into public.meeting_schedules (coach_id, student_id, first_date, start_time, repeat_weekly)
  values ($1, $2, $3, '12:00', false) returning id`, [A.coach, can, today])).id;
const mark = async (s, st) => (await one(`select public.set_meeting_status($1, $2, $3) r`, [s, today, st])).r;

console.log('Gelmedi → veliye mesaj');
check(await mark(s1, 'held') === null, 'yapıldı: mesaj yok');
await asSuper();
check((await outbox()).length === 0, 'kuyruk boş');
await asUser(A.coach);
check(await mark(s1, 'missed') === 'notified', 'gelmedi: veliye mesaj sıraya alındı');
await asSuper();
let o = await outbox();
check(o.length === 1 && o[0].phone === '+905321112233' && o[0].student_id === ahmet
  && o[0].created_by === A.coach && o[0].channel === 'whatsapp' && o[0].template === null, 'mesaj veli telefonuna, genel şablonla', o);
check(o[0].body.includes('Fatma Demir') && o[0].body.includes('Bal Akademi') && o[0].body.includes('Ahmet Demir')
  && o[0].body.includes(tr) && o[0].body.includes('11:00') && o[0].body.includes('Bal Akademi Koç')
  && o[0].body.includes('gelmedi'), 'metinde veli, kurum, öğrenci, tarih, saat, koç', o[0].body);

await asUser(A.coach);
check(await mark(s1, 'missed') === null, 'ikinci kez işaretleme: mesaj yok');
await mark(s1, null);
check(await mark(s1, 'missed') === null, 'işaret kaldırılıp yeniden konunca da mesaj yok');
await asSuper();
check((await outbox()).length === 1, 'aynı görüşme için tek mesaj');

await asUser(A.coach);
check(await mark(s2, 'missed') === 'no_phone', 'veli telefonu yoksa no_phone');
await asSuper();
check((await outbox()).length === 1, 'telefonsuz öğrenci için mesaj yok');
check((await one(`select status from public.meeting_occurrences where schedule_id = $1`, [s2])).status === 'missed', 'işaret yine de kaydedildi');

await asUser(A.admin);
await expectError('müdür işaretleyemez', () => mark(s1, 'missed'), 'NOT_ALLOWED');
await asUser(ahmet);
await expectError('öğrenci işaretleyemez', () => mark(s1, 'held'), 'NOT_ALLOWED');
await asAnon();
await expectError('anonim çağıramaz', () => mark(s1, 'missed'));

console.log('Geri alma');
await asSuper();
await db.exec(read(rbDir, '20261112110000_meeting_missed_whatsapp.down.sql'));
await asUser(A.coach);
await db.query(`select public.set_meeting_status($1, $2, 'held')`, [s2, today]);
ok('eski fonksiyon çalışıyor');
await asSuper();
await db.exec(read(migDir, '20261112110000_meeting_missed_whatsapp.sql'));
ok('yeniden uygulandı');

console.log(failures ? `\n${failures} FAIL` : '\nhepsi geçti');
process.exit(failures ? 1 : 0);
