// Eğitim: günlük soru hakları (Türkçe/Matematik 20, diğerleri 10), kimin
// gördüğü, değiştirilemezlik, geri alma / yeniden uygulama.
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


const A = await school('Bal Akademi', 'ADMINPR1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');
await asUser(ahmet);
const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, 'Ahmet Veli');
const B = await school('Yıldız', 'ADMINPR2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

const answer = (subject, i, correct = true) => db.query(
  `insert into public.practice_answers (student_id, subject_code, question_id, correct) values ($1, $2, $3, $4)`,
  [ahmet, subject, `${subject}-${String(i).padStart(4, '0')}`, correct]);

console.log('Günlük hak');
await asUser(ahmet);
for (let i = 1; i <= 20; i++) await answer('TYT_MAT', i, i % 3 !== 0);
ok('Matematik: 20 cevap kaydedildi');
await expectError('Matematik: 21. cevap reddedilir', () => answer('TYT_MAT', 21), 'DAILY_LIMIT');
for (let i = 1; i <= 10; i++) await answer('TYT_FIZ', i);
await expectError('Fizik: 11. cevap reddedilir', () => answer('TYT_FIZ', 11), 'DAILY_LIMIT');
await answer('TYT_TUR', 1);
ok('başka dersin hakkı ayrı sayılır');

console.log('Doğrulama');
await expectError('ders kodu denetlenir', () => db.query(`insert into public.practice_answers (student_id, subject_code, question_id, correct) values ($1, 'AYT_MAT', 'AYT_MAT-0001', true)`, [ahmet]));
await expectError('soru kimliği dersle uyumlu olmalı', () => db.query(`insert into public.practice_answers (student_id, subject_code, question_id, correct) values ($1, 'TYT_KIM', 'TYT_BIY-0001', true)`, [ahmet]));
await expectError('başkası adına cevap yazılamaz', () => db.query(`insert into public.practice_answers (student_id, subject_code, question_id, correct) values ($1, 'TYT_KIM', 'TYT_KIM-0001', true)`, [can]));
await expectError('cevap değiştirilemez', () => db.query(`update public.practice_answers set correct = true where student_id = $1`, [ahmet]), 'permission denied');
await expectError('cevap silinemez', () => db.query(`delete from public.practice_answers where student_id = $1`, [ahmet]), 'permission denied');
await asSuper();
check((await one(`select count(*)::int c from public.practice_answers where answered_on = ((now() at time zone 'Europe/Istanbul')::date)`)).c === 31, 'tarih sunucuda atanır (bugün)');

console.log('Dün çözülenler bugünün hakkından düşmez');
await db.query(`update public.practice_answers set answered_on = answered_on - 1 where subject_code = 'TYT_FIZ'`);
await asUser(ahmet);
await answer('TYT_FIZ', 11);
ok('ertesi gün yeni hak');
await expectError('istemci geçmiş tarih yazamaz (yine bugüne sayılır)', async () => {
  for (let i = 12; i <= 30; i++) {
    await db.query(`insert into public.practice_answers (student_id, subject_code, question_id, correct, answered_on) values ($1, 'TYT_FIZ', $2, true, '2020-01-01')`, [ahmet, `TYT_FIZ-${String(i).padStart(4, '0')}`]);
  }
}, 'DAILY_LIMIT');

console.log('Kimler görür');
const seen = async (who) => { await asUser(who); return (await one(`select count(*)::int c from public.practice_answers`)).c; };
const total = await seen(ahmet);
check(total > 0, 'öğrenci kendi cevaplarını görür', total);
check(await seen(A.coach) === total, 'koçu görür');
check(await seen(parent) === total, 'velisi görür');
check(await seen(can) === 0, 'sınıf arkadaşı göremez');
check(await seen(zeynep) === 0, 'başka dershane göremez');
await asUser(A.coach);
await expectError('koç cevap yazamaz', () => db.query(`insert into public.practice_answers (student_id, subject_code, question_id, correct) values ($1, 'TYT_KIM', 'TYT_KIM-0001', true)`, [ahmet]));

console.log('Hesap silme');
await db.query(`select public.delete_student_account($1)`, [ahmet]);
await asSuper();
check((await one(`select count(*)::int c from public.practice_answers where student_id = $1`, [ahmet])).c === 0, 'hesap silinince cevaplar da silinir');

console.log('Geri alma ve yeniden uygulama');
const name = '20261018200000_practice';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.practice_answers') t`)).t === null, 'tablo kalktı');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select to_regclass('public.practice_answers') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
