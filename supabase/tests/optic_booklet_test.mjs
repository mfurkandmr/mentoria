// Optik okuma, kitapçık türü (20261030110000_optic_booklets): B kitapçığı
// numaraları, değerlendirme, hatalar, geri alma.
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
const all = async (sql, p = []) => (await db.query(sql, p)).rows;
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

const a = await school('Anka', 'ANKA-ADMIN');
const coach = await coachIn(a.admin, 'Anka Koç');
const ali = await signUp(coach.code, 'Ali');
const ayse = await signUp(coach.code, 'Ayşe');

const createKey = (list) => db.query(
  `select public.create_answer_key('Kasım TYT-1', 'TYT', null, null, 'mentoria_yks', $1) id`,
  [JSON.stringify(list)]).then((r) => r.rows[0].id);
const submit = (student, answers, booklet, k) => db.query(
  booklet === undefined
    ? `select public.submit_optic($1, $2, $3) r`
    : `select public.submit_optic($1, $2, $3, $4) r`,
  booklet === undefined ? [k, student, JSON.stringify(answers)] : [k, student, JSON.stringify(answers), booklet],
).then((r) => r.rows[0].r);

await asUser(coach.id);
await expectError('B numarası ders soru sayısını aşamaz',
  () => createKey([{ subject: 'TYT_FIZ', no: 1, no_b: 8, correct: 'A' }]), 'INVALID_ITEMS');
await expectError('aynı B numarası iki soruya verilemez', () => createKey([
  { subject: 'TYT_MAT', no: 1, no_b: 1, correct: 'A' },
  { subject: 'TYT_MAT', no: 2, no_b: 1, correct: 'B' },
]), 'INVALID_ITEMS');

const key = await createKey([
  { subject: 'TYT_MAT', no: 1, no_b: 2, correct: 'C', outcome: 'Trigonometri' },
  { subject: 'TYT_MAT', no: 2, no_b: 1, correct: 'A', outcome: 'Üslü sayılar' },
  { subject: 'TYT_TUR', no: 1, no_b: 1, correct: 'B' },
]);

// B kitapçığı: öğrencinin 1. işareti A'daki 2. soru, 2. işareti A'daki 1. soru.
let r = await submit(ali, { TYT_MAT: ['A', 'C'], TYT_TUR: ['B'] }, 'b', key);
check(r.correct === 3 && r.wrong === 0, 'B kitapçığı doğru değerlendirildi', r);
await asSuper();
check((await one(`select booklet from public.exams where id = $1`, [r.exam_id])).booklet === 'B', 'denemede kitapçık B');
let rows = await all(`select a.question_no, a.booklet_no, a.marked from public.exam_answers a
  join public.subjects s on s.id = a.subject_id where a.exam_id = $1 and s.code = 'TYT_MAT' order by 1`, [r.exam_id]);
check(JSON.stringify(rows) === JSON.stringify([
  { question_no: 1, booklet_no: 2, marked: 'C' },
  { question_no: 2, booklet_no: 1, marked: 'A' },
]), 'kayıtlar A numarasıyla, öğrencinin numarası booklet_no', rows);

// Varsayılan A (eski 3 parametreli çağrı da çalışır).
await asUser(coach.id);
r = await submit(ayse, { TYT_MAT: ['A', 'C'], TYT_TUR: ['B'] }, undefined, key);
check(r.correct === 1 && r.wrong === 2, 'A kitapçığında aynı işaretler 1 doğru', r);
await asSuper();
check((await one(`select booklet from public.exams where id = $1`, [r.exam_id])).booklet === 'A', 'denemede kitapçık A');
check((await one(`select booklet_no from public.exam_answers where exam_id = $1 limit 1`, [r.exam_id])).booklet_no === null,
  'A kitapçığında booklet_no boş');

await asUser(coach.id);
await expectError('geçersiz kitapçık', () => submit(ayse, {}, 'E', key), 'INVALID_BOOKLET');
const noB = await createKey([{ subject: 'TYT_MAT', no: 1, correct: 'C' }]);
await expectError('B numarası olmayan anahtarla B okunamaz', () => submit(ayse, { TYT_MAT: ['C'] }, 'B', noB), 'NO_B_KEY');

// --- Geri alma / yeniden uygulama ----------------------------------------------------
const name = '20261030110000_optic_booklets';
await asSuper();
// Bu migration'a bağlı sonraki migration'lar önce geri alınır.
const laterDeps = migs.filter((f) => f >= '20261105170000_exam_import.sql').map((f) => f.replace('.sql', '')).reverse();
for (const l of laterDeps) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select count(*) n from information_schema.columns
  where table_name = 'exams' and column_name = 'booklet'`)).n == 0, 'geri alındı');
await asUser(coach.id);
r = await db.query(`select public.submit_optic($1, $2, $3) r`, [noB, ali, JSON.stringify({ TYT_MAT: ['C'] })]).then((x) => x.rows[0].r);
check(r.correct === 1, 'eski submit_optic çalışıyor', r);
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
for (const l of [...laterDeps].reverse()) await db.exec(read(migDir, `${l}.sql`));
check((await one(`select count(*) n from information_schema.columns
  where table_name = 'answer_key_items' and column_name = 'question_no_b'`)).n == 1, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
