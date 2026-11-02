// Öğrencinin kendi çalışma programı: kendine saatli madde ekler, yalnızca
// kendi eklediğini siler; koçun maddesine dokunamaz; geri alma.
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
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  return { admin, coach, org, code: (await one(`select public.create_invite('student', null, 10) c`)).c };
}
const add = (student, d, extra = {}) => db.query(
  `insert into public.plan_items (student_id, day, subject_code, topic, minutes, start_time)
   values ($1, $2::date, $3, $4, $5, $6::time) returning id`,
  [student, d, extra.subject ?? 'TYT_MAT', extra.topic ?? 'Problemler', extra.m ?? 45, extra.at ?? null]);
const row = async (id) => { await asSuper(); return one(`select start_time::text t, created_by from public.plan_items where id = $1`, [id]); };

const A = await school('Bal Akademi', 'ADMINSP1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');
await asUser(ahmet);
const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, 'Ahmet Veli');
await asSuper();
const d0 = (await one(`select ((now() at time zone 'Europe/Istanbul')::date)::text d`)).d;
const past = (await one(`select (((now() at time zone 'Europe/Istanbul')::date) - 8)::text d`)).d;

console.log('Öğrenci kendine program yapar');
await asUser(ahmet);
const own = (await add(ahmet, d0, { at: '09:00:37', subject: 'TYT_TUR', topic: 'Paragraf' })).rows[0].id;
let r = await row(own);
check(r.t === '09:00:00' && r.created_by === ahmet, 'saatli madde eklenir, saniye atılır', r);
await asUser(ahmet);
const noTime = (await add(ahmet, d0, { at: null })).rows[0].id;
check((await row(noTime)).t === null, 'saat isteğe bağlı');
await asUser(ahmet);
await expectError('sınıf arkadaşına ekleyemez', () => add(can, d0));
await expectError('geçmiş haftaya ekleyemez', () => add(ahmet, past), 'PLAN_DAY_PAST');
await asUser(parent);
await expectError('veli kendine plan yazamaz', () => add(parent, d0));
await expectError('veli çocuğuna plan yazamaz', () => add(ahmet, d0));
await asSuper();
check((await one(`select count(*)::int c from public.notifications where user_id = $1 and kind = 'plan'`, [ahmet])).c === 0, 'kendi maddesi bildirim üretmez');

console.log('Koçun maddesi ile karışmaz');
await asUser(A.coach);
const coachItem = (await add(ahmet, d0, { at: '14:30' })).rows[0].id;
ok('koç da saatli madde ekler');
await asUser(ahmet);
r = await db.query(`delete from public.plan_items where id = $1`, [coachItem]);
check(r.affectedRows === 0, 'öğrenci koçun maddesini silemez');
await expectError('öğrenci saati değiştiremez', () => db.query(`update public.plan_items set start_time = '10:00' where id = $1`, [own]), 'permission denied');
await db.query(`update public.plan_items set done_at = now() where id = $1`, [own]);
ok('kendi maddesini işaretler');
r = await db.query(`delete from public.plan_items where id = $1`, [own]);
check(r.affectedRows === 1, 'kendi eklediğini siler');
await asUser(A.coach);
r = await db.query(`delete from public.plan_items where id = $1`, [noTime]);
check(r.affectedRows === 1, 'koç öğrencinin eklediğini de silebilir');
await asUser(A.coach);
const seen = (await one(`select count(*)::int c from public.plan_items where student_id = $1`, [ahmet])).c;
check(seen === 1, 'koç görür');

console.log('Günde en çok 12 madde');
await asUser(ahmet);
const d3 = (await (async () => { await asSuper(); return one(`select (((now() at time zone 'Europe/Istanbul')::date) + 3)::text d`); })()).d;
await asUser(ahmet);
for (let i = 0; i < 12; i++) await add(ahmet, d3, { topic: `Konu ${i}` });
await expectError('13. madde reddedilir', () => add(ahmet, d3), 'PLAN_DAY_FULL');

console.log('Geri alma ve yeniden uygulama');
const name = '20261031100000_student_self_plan';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select count(*)::int c from information_schema.columns where table_name = 'plan_items' and column_name = 'start_time'`)).c === 0, 'sütun kalktı');
await asUser(ahmet);
await expectError('geri alınınca öğrenci ekleyemez', () => db.query(`insert into public.plan_items (student_id, day, subject_code) values ($1, $2::date, 'TYT_MAT')`, [ahmet, d0]));
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
await asUser(ahmet);
await add(ahmet, d0, { at: '08:00' });
ok('yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
