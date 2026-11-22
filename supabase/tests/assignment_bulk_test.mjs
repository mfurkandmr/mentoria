// Toplu ödev (20261121100000_assignment_bulk).
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
async function expectError(n, fn, pattern) {
  try { await fn(); bad(n, 'hata bekleniyordu'); }
  catch (e) { (!pattern || e.message.includes(pattern)) ? ok(n) : bad(n, e.message); }
}
async function signUp(code, name) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true,
      privacy_version: '1.0' })])).id;
}
async function school(name, code, students = 1) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 60) returning id`, [name]));
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org.id]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const list = [];
  for (let i = 0; i < students; i++) {
    await asUser(coach);
    list.push(await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, `${name} Öğrenci ${i}`));
  }
  return { org: org.id, admin, coach, students: list };
}
const A = await school('Bal Akademi', 'ADMINBK1', 3);
const B = await school('Arı Kurs', 'ADMINBK2', 1);
const items = JSON.stringify([{ subject_code: 'TYT_MAT', note: 'Konu anlatımı + test' }]);

console.log('Toplu gönderme');
await asUser(A.coach);
const ids = (await one(`select public.send_assignment_bulk($1::uuid[], 'Haftalık ödev', $2::jsonb) ids`,
  [A.students, items])).ids;
check(ids.length === 3, 'her öğrenciye bir ödev kimliği', ids);
await asSuper();
check((await one(`select count(*)::int c from public.assignments where title = 'Haftalık ödev'`)).c === 3,
  'üç ayrı ödev kaydı');
check((await one(`select count(distinct student_id)::int c from public.assignments where title = 'Haftalık ödev'`)).c === 3,
  'her öğrenciye bir tane');
check((await one(`select count(*)::int c from public.notifications where kind = 'assignment'`)).c === 3,
  'her öğrenciye bildirim');
check((await one(`select count(*)::int c from public.assignment_items where question_count is null`)).c === 3,
  'soru sayısı olmadan (yalnızca konu/not) kaydedilir');

console.log('Yinelenen öğrenci');
await asUser(A.coach);
const dup = (await one(`select public.send_assignment_bulk($1::uuid[], 'Yinelenen', $2::jsonb) ids`,
  [[A.students[0], A.students[0]], items])).ids;
check(dup.length === 1, 'aynı öğrenci iki kez verilse tek ödev', dup);

console.log('Reddedilenler');
await expectError('boş liste', () => db.query(`select public.send_assignment_bulk('{}'::uuid[], 'x', $1::jsonb)`, [items]), 'NO_STUDENTS');
await asUser(A.coach);
const before = (await (async () => { await asSuper(); return one(`select count(*)::int c from public.assignments`); })()).c;
await asUser(A.coach);
await expectError('başka kurumun öğrencisi varsa hepsi reddedilir', () =>
  db.query(`select public.send_assignment_bulk($1::uuid[], 'Karışık', $2::jsonb)`,
    [[A.students[0], B.students[0]], items]), 'NOT_ALLOWED');
await asSuper();
check((await one(`select count(*)::int c from public.assignments`)).c === before, 'hepsi ya da hiçbiri: hiçbir kayıt kalmadı');
await asUser(A.coach);
const many = Array.from({ length: 31 }, (_, i) => A.students[0]);
// 31 yinelenen tek kişiye iner; sınır gerçekten farklı kimlikle denenir.
await expectError('30 öğrenciden fazlası', () =>
  db.query(`select public.send_assignment_bulk(array(select gen_random_uuid() from generate_series(1, 31)), 'x', $1::jsonb)`, [items]),
  'TOO_MANY_STUDENTS');
await asUser(A.students[0]);
await expectError('öğrenci toplu ödev veremez', () =>
  db.query(`select public.send_assignment_bulk($1::uuid[], 'x', $2::jsonb)`, [[A.students[0]], items]), 'NOT_ALLOWED');

console.log('Günlük sınır');
await asSuper();
await db.query(`insert into public.assignments (coach_id, student_id, title)
  select $1, $2, 'dolgu' from generate_series(1, 299)`, [A.coach, A.students[0]]);
await asUser(A.coach);
await expectError('300 ödev sınırı', () =>
  db.query(`select public.send_assignment_bulk($1::uuid[], 'x', $2::jsonb)`, [A.students, items]), 'ASSIGNMENT_DAILY_LIMIT');

console.log('Geri alma');
await asSuper();
await db.exec(read(rbDir, '20261121100000_assignment_bulk.down.sql'));
check((await one(`select count(*)::int c from pg_proc where proname = 'send_assignment_bulk'`)).c === 0, 'rollback fonksiyonu kaldırır');
await db.exec(read(migDir, '20261121100000_assignment_bulk.sql'));
check((await one(`select count(*)::int c from pg_proc where proname = 'send_assignment_bulk'`)).c === 1, 're-apply çalışır');

if (failures) { console.log(`\n${failures} test BAŞARISIZ`); process.exit(1); }
console.log('\nTüm toplu ödev testleri geçti');
