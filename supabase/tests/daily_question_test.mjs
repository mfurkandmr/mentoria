// Günün Sorusu: günlük tek soru, yalnızca o günün sorusu kabul, seri,
// sabah bildirimi, kimin gördüğü; geri alma / yeniden uygulama.
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



const A = await school('Bal Akademi', 'ADMINDQ1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');
const B = await school('Yıldız', 'ADMINDQ2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

await asSuper();
const today = (await one(`select ((now() at time zone 'Europe/Istanbul')::date)::text d`)).d;
const qid = async (who, day) => (await one(`select public.daily_question_id($1, $2::date) q`, [who, day])).q;

console.log('Sorunun seçimi');
const q1 = await qid(ahmet, today);
check(/^TYT_[A-Z]{3}-\d{4}$/.test(q1), 'kimlik havuz biçiminde', q1);
check(q1 === await qid(ahmet, today), 'aynı gün aynı soru');
const days = [];
for (let i = 0; i < 9; i++) days.push((await qid(ahmet, (await one(`select ($1::date + $2::int)::text d`, [today, i])).d)).split('-')[0]);
check(new Set(days).size === 9, 'dokuz günde dokuz farklı ders', days);
let maxIdx = 0;
for (let i = 0; i < 200; i++) {
  const q = await qid(ahmet, (await one(`select ($1::date + $2::int)::text d`, [today, i])).d);
  const [subj, n] = q.split('-');
  const limit = ['TYT_TUR', 'TYT_MAT'].includes(subj) ? 600 : 300;
  if (+n < 1 || +n > limit) bad('havuz sınırı', q);
  maxIdx = Math.max(maxIdx, +n);
}
ok('200 günde hiçbir kimlik havuz dışına çıkmaz');

console.log('Cevap');
await asUser(ahmet);
let info = (await one(`select public.my_daily_question() d`)).d;
check(info.question_id === q1 && info.answered === false && info.streak === 0, 'bugünkü soru, cevapsız, seri 0', info);
await expectError('başka bir soru kabul edilmez', () => db.query(`insert into public.daily_answers (student_id, question_id, correct) values ($1, 'TYT_MAT-0001', true)`, [ahmet]), 'NOT_TODAYS_QUESTION');
await db.query(`insert into public.daily_answers (student_id, question_id, correct) values ($1, $2, true)`, [ahmet, q1]);
info = (await one(`select public.my_daily_question() d`)).d;
check(info.answered === true && info.correct === true && info.streak === 1, 'cevaplandı, seri 1', info);
await expectError('günde ikinci cevap yok', () => db.query(`insert into public.daily_answers (student_id, question_id, correct) values ($1, $2, false)`, [ahmet, q1]));
await expectError('cevap değiştirilemez', () => db.query(`update public.daily_answers set correct = false where student_id = $1`, [ahmet]), 'permission denied');
await asSuper();
const canQ = await qid(can, today);
await asUser(ahmet);
await expectError('başkası adına cevap yazılamaz', () => db.query(`insert into public.daily_answers (student_id, question_id, correct) values ($1, $2, true)`, [can, canQ]));

console.log('Seri');
await asSuper();
// Önceki iki gün doğru, üç gün önce yanlış.
for (const [k, correct] of [[1, true], [2, true], [3, false], [4, true]]) {
  const d = (await one(`select ($1::date - $2::int)::text d`, [today, k])).d;
  await db.query(`alter table public.daily_answers disable trigger guard_daily_answer`);
  await db.query(`insert into public.daily_answers (student_id, tenant_id, answered_on, question_id, correct) select $1, tenant_id, $2::date, 'TYT_MAT-0001', $3 from public.profiles where id = $1`, [ahmet, d, correct]);
  await db.query(`alter table public.daily_answers enable trigger guard_daily_answer`);
}
await asUser(ahmet);
info = (await one(`select public.my_daily_question() d`)).d;
check(info.streak === 3, 'bugün + önceki 2 gün = 3 (yanlış gün seriyi keser)', info);
await asUser(can);
check((await one(`select public.my_daily_question() d`)).d.streak === 0, 'Can: seri 0');
await asUser(A.coach);
check((await one(`select public.my_daily_question() d`)).d === null, 'öğrenci olmayana soru yok');

console.log('Sabah bildirimi');
await asSuper();
let n = (await one(`select public.send_daily_questions() n`)).n;
const got = (await db.query(`select user_id from public.notifications where kind = 'daily_question'`)).rows.map((r) => r.user_id);
check(n === got.length && got.includes(can) && got.includes(zeynep) && !got.includes(ahmet), 'cevaplamayan öğrencilere gider', got.length);
check(!got.includes(A.coach), 'koça gitmez');
check((await one(`select public.send_daily_questions() n`)).n === 0, 'aynı gün ikinci kez gitmez');
await asUser(can);
await expectError('istemci tetikleyemez', () => db.query(`select public.send_daily_questions()`), 'permission denied');

console.log('Kimler görür');
const seen = async (who) => { await asUser(who); return (await one(`select count(*)::int c from public.daily_answers`)).c; };
check(await seen(ahmet) === 5, 'öğrenci kendininkileri görür');
check(await seen(A.coach) === 5, 'koçu görür');
check(await seen(can) === 0, 'sınıf arkadaşı göremez');
check(await seen(zeynep) === 0, 'başka dershane göremez');

console.log('Geri alma ve yeniden uygulama');
const name = '20261018210000_daily_question';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.daily_answers') t`)).t === null, 'tablo kalktı');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select to_regclass('public.daily_answers') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
