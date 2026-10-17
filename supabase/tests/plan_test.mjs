// Haftalık plan (kim ekler, işaretler, görür) ve deneme eğilimi
// (son 5 deneme, yalnızca yönetilen öğrenciler); geri alma.
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




const A = await school('Bal Akademi', 'ADMINPL1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');
const ece = await signUp(A.code, 'Ece Tan');
await asUser(ahmet);
const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, 'Ahmet Veli');
const B = await school('Yıldız', 'ADMINPL2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

const today = async () => { await asSuper(); return (await one(`select ((now() at time zone 'Europe/Istanbul')::date)::text d`)).d; };
const day = async (k) => { await asSuper(); return (await one(`select (((now() at time zone 'Europe/Istanbul')::date) + $1::int)::text d`, [k])).d; };
const add = (student, d, extra = {}) => db.query(
  `insert into public.plan_items (student_id, day, subject_code, topic, question_count, minutes, note)
   values ($1, $2::date, $3, $4, $5, $6, $7) returning id`,
  [student, d, extra.subject ?? 'TYT_MAT', extra.topic ?? 'Problemler', extra.q ?? 40, extra.m ?? null, extra.note ?? null]);

console.log('Plan: kim ekler');
const d0 = await today();
const d1 = await day(1);
await asUser(A.coach);
const item = (await add(ahmet, d0)).rows[0].id;
await add(ahmet, d1, { subject: 'AYT_FIZ', topic: 'Atışlar', q: null, m: 60 });
ok('koç öğrencisine plan ekler');
await asUser(A.admin);
await add(can, d0, { subject: 'TYT_TUR', topic: 'Paragraf' });
ok('müdür kurumundaki öğrenciye plan ekler');
await asUser(B.coach);
await expectError('başka dershanenin koçu ekleyemez', () => add(ahmet, d0));
await asUser(ahmet);
await expectError('öğrenci kendine madde ekleyemez', () => add(ahmet, d0));
await asUser(A.coach);
await expectError('geçmiş haftaya eklenemez', async () => add(ahmet, await day(-8)), 'PLAN_DAY_PAST');
await expectError('ders kodu denetlenir', () => add(ahmet, d0, { subject: 'MAT' }));
await expectError('koça plan yazılamaz', () => add(A.coach, d0), 'PLAN_NOT_STUDENT');
await asSuper();
check((await one(`select created_by from public.plan_items where id = $1`, [item])).created_by === A.coach, 'ekleyen sunucuda yazılır');

console.log('Plan: işaretleme');
await asUser(ahmet);
await db.query(`update public.plan_items set done_at = '2000-01-01' where id = $1`, [item]);
await asSuper();
const done = (await one(`select done_at > now() - interval '1 minute' ok from public.plan_items where id = $1`, [item])).ok;
check(done === true, 'öğrenci yaptım işaretler, zaman sunucudan');
await asUser(ahmet);
await expectError('öğrenci maddeyi değiştiremez', () => db.query(`update public.plan_items set topic = 'x' where id = $1`, [item]), 'permission denied');
await expectError('öğrenci silemez', async () => {
  const r = await db.query(`delete from public.plan_items where id = $1`, [item]);
  if (r.affectedRows === 0) throw new Error('permission denied (0 satır)');
}, 'permission denied');
await db.query(`update public.plan_items set done_at = null where id = $1`, [item]);
await asSuper();
check((await one(`select done_at from public.plan_items where id = $1`, [item])).done_at === null, 'işaret geri alınır');
await asUser(can);
const r = await db.query(`update public.plan_items set done_at = now() where id = $1`, [item]);
check(r.affectedRows === 0, 'başkasının maddesini işaretleyemez');

console.log('Plan: kim görür');
const seen = async (who) => { await asUser(who); return (await one(`select count(*)::int c from public.plan_items where student_id = $1`, [ahmet])).c; };
check(await seen(ahmet) === 2, 'öğrenci kendi planını görür');
check(await seen(A.coach) === 2, 'koçu görür');
check(await seen(parent) === 2, 'velisi görür');
check(await seen(can) === 0, 'sınıf arkadaşı göremez');
check(await seen(zeynep) === 0, 'başka dershane göremez');

console.log('Plan: günde en çok 12 madde');
await asUser(A.coach);
const d2 = await day(2);
await asUser(A.coach);
for (let i = 0; i < 12; i++) await add(ece, d2, { topic: `Konu ${i}` });
await expectError('13. madde reddedilir', () => add(ece, d2), 'PLAN_DAY_FULL');
await asUser(A.coach);
check((await db.query(`delete from public.plan_items where student_id = $1 and day = $2::date`, [ece, d2])).affectedRows === 12, 'koç silebilir');

console.log('Deneme eğilimi');
await asSuper();
const subj = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
const exam = async (student, k, net, type = 'TYT') => {
  const e = (await one(`insert into public.exams (student_id, exam_type, name, taken_on) values ($1, $2, $3, current_date - $4::int) returning id`, [student, type, `D${k}`, 100 - k])).id;
  await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct, wrong) values ($1, $2, $3, 0)`, [e, subj, net]);
};
// Ahmet: 7 deneme; son 5'i 30 → 50 (+20). Eski iki deneme (80) sayılmaz.
for (const [k, n] of [[1, 80], [2, 80], [3, 30], [4, 35], [5, 40], [6, 45], [7, 50]]) await exam(ahmet, k, n);
// Can: 60 → 42 (−18). Ece: tek deneme (listelenmez).
for (const [k, n] of [[1, 60], [2, 55], [3, 42]]) await exam(can, k, n);
await exam(ece, 1, 40);
await exam(zeynep, 1, 10); await exam(zeynep, 2, 70);
const trends = async (who, type = 'TYT') => { await asUser(who); return (await db.query(`select * from public.exam_trends($1)`, [type])).rows; };
let t = await trends(A.coach);
const ta = t.find((x) => x.student_id === ahmet), tc = t.find((x) => x.student_id === can);
check(t.length === 2, 'en az 2 denemesi olanlar, yalnızca kendi öğrencileri', t.map((x) => x.full_name));
check(Number(ta.first_net) === 30 && Number(ta.last_net) === 50 && Number(ta.delta) === 20 && ta.exam_count === 5, 'Ahmet: son 5 denemede +20', ta);
check(Number(tc.delta) === -18, 'Can: −18', tc);
check(t[0].student_id === ahmet, 'yükselenden düşene sıralı');
t = await trends(A.admin);
check(t.length === 2, 'müdür kurumundakileri görür');
t = await trends(B.coach);
check(t.length === 1 && t[0].student_id === zeynep && Number(t[0].delta) === 60, 'Yıldız koçu yalnızca kendi öğrencisini (Zeynep +60) görür', t);
t = await trends(ahmet);
check(t.length === 0, 'öğrenci kimseyi göremez');
check((await trends(A.coach, 'AYT')).length === 0, 'AYT ayrı sayılır');

console.log('Geri alma ve yeniden uygulama');
const name = '20261018240000_plan_and_trends';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.plan_items') t`)).t === null, 'tablo kalktı');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select to_regclass('public.plan_items') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
