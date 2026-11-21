// Maarif müfredatı (20261121110000_maarif_curriculum + seed_maarif_topics.sql).
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';

const root = process.argv[2] ?? '../..';
const migDir = `${root}/supabase/migrations`;
const rbDir = `${root}/supabase/rollbacks`;
const migs = fs.readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort();
const read = (d, f) => fs.readFileSync(`${d}/${f}`, 'utf8');
const seed = read(`${root}/supabase`, 'seed.sql') + '\n' + read(`${root}/supabase`, 'seed_ayt_ydt_topics.sql');
const maarifSeed = read(`${root}/supabase`, 'seed_maarif_topics.sql');

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
await db.exec(maarifSeed);
ok(`${migs.length} migration + seed + maarif seed`);

const asSuper = () => db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
const asUser = (id) => db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
const one = async (sql, p = []) => (await db.query(sql, p)).rows[0];
const rows = async (sql, p = []) => (await db.query(sql, p)).rows;
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
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name]));
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org.id]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const student = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, `${name} Öğrenci`);
  return { admin, coach, student };
}
const A = await school('Bal Akademi', 'ADMINMC1');
const B = await school('Arı Kurs', 'ADMINMC2');

console.log('Katalog');
await asSuper();
const total = (await one(`select count(*)::int c from public.topics where curriculum = 'maarif'`)).c;
check(total > 400, 'Maarif konuları yüklendi', total);
check((await one(`select count(*)::int c from public.topics where curriculum = 'eski' and grade is not null`)).c === 0,
  'eski konuların sınıfı yok');
check((await one(`select count(*)::int c from public.topics where curriculum = 'maarif' and (group_name is null or source_url is null)`)).c === 0,
  'her Maarif konusunun teması ve kaynağı var');
check((await one(`select count(*)::int c from public.topics where curriculum = 'maarif' and source_url not like 'https://tymm.meb.gov.tr/%'`)).c === 0,
  'kaynak yalnızca resmî TYMM sitesi');
const subj = (await rows(`select distinct s.code from public.topics t join public.subjects s on s.id = t.subject_id where t.curriculum = 'maarif' order by 1`)).map((r) => r.code);
check(['AYT_EDB', 'TYT_BIY', 'TYT_COG', 'TYT_DIN', 'TYT_FEL', 'TYT_FIZ', 'TYT_KIM', 'TYT_MAT', 'TYT_TAR'].every((c) => subj.includes(c)),
  'çekirdek dersler var', subj);
check((await one(`select count(*)::int c from (select subject_id, grade, name from public.topics where curriculum = 'maarif' group by 1,2,3 having count(*) > 1) d`)).c === 0,
  'ders/sınıf/ad tekil');
const eski = (await one(`select count(*)::int c from public.topics where curriculum = 'eski'`)).c;
await db.exec(maarifSeed);
check((await one(`select count(*)::int c from public.topics where curriculum = 'maarif'`)).c === total, 'seed tekrar çalışınca çoğalmaz');
check((await one(`select count(*)::int c from public.topics where curriculum = 'eski'`)).c === eski, 'eski konulara dokunulmadı');

console.log('Kısıtlar');
await expectError('Maarif konusu sınıfsız olamaz', () => db.query(
  `insert into public.topics (subject_id, name, curriculum) select id, 'x', 'maarif' from public.subjects limit 1`), 'topics_curriculum_grade');
await expectError('eski konuya sınıf verilemez', () => db.query(
  `insert into public.topics (subject_id, name, grade) select id, 'x', 9 from public.subjects limit 1`), 'topics_curriculum_grade');
await expectError('bilinmeyen müfredat', () => db.query(
  `insert into public.topics (subject_id, name, curriculum) select id, 'x', 'foo' from public.subjects limit 1`));

console.log('Öğrenci müfredatı');
await asUser(A.student);
await db.query(`select public.set_curriculum($1, 'maarif')`, [A.student]);
await asSuper();
check((await one(`select curriculum c from public.profiles where id = $1`, [A.student])).c === 'maarif', 'öğrenci kendi müfredatını seçer');
await asUser(A.coach);
await db.query(`select public.set_curriculum($1, 'eski')`, [A.student]);
await asSuper();
check((await one(`select curriculum c from public.profiles where id = $1`, [A.student])).c === 'eski', 'koç öğrencisininkini değiştirir');
await asUser(A.coach);
await db.query(`select public.set_curriculum($1, null)`, [A.student]);
await asSuper();
check((await one(`select curriculum c from public.profiles where id = $1`, [A.student])).c === null, 'boş = sınıftan türetilir');
await asUser(B.coach);
await expectError('başka kurumun koçu değiştiremez', () => db.query(`select public.set_curriculum($1, 'maarif')`, [A.student]), 'NOT_ALLOWED');
await asUser(A.student);
await expectError('geçersiz müfredat', () => db.query(`select public.set_curriculum($1, 'xyz')`, [A.student]), 'BAD_CURRICULUM');
const visible = (await one(`select count(*)::int c from public.topics where curriculum = 'maarif'`)).c;
check(visible === total, 'öğrenci Maarif konularını okuyabilir', visible);

console.log('Ödev: Maarif konusu');
await asSuper();
const tid = (await one(`select t.id from public.topics t join public.subjects s on s.id = t.subject_id
  where t.curriculum = 'maarif' and s.code = 'TYT_MAT' and t.grade = 9 limit 1`)).id;
await asUser(A.coach);
const ids = JSON.stringify([{ subject_code: 'TYT_MAT', topic_id: tid, note: '2 test' }]);
const asg = (await one(`select public.send_assignment($1, 'Maarif ödevi', $2::jsonb) id`, [A.student, ids])).id;
await asSuper();
const item = await one(`select topic_id, note, question_count from public.assignment_items where assignment_id = $1`, [asg]);
check(item.topic_id === tid && item.note === '2 test' && item.question_count === null, 'Maarif konusuna ödev (soru sayısız) verilir', item);

console.log('Geri alma');
await asSuper();
await db.exec(read(rbDir, '20261121110000_maarif_curriculum.down.sql'));
check((await one(`select count(*)::int c from information_schema.columns where table_name = 'topics' and column_name = 'curriculum'`)).c === 0, 'rollback sütunları kaldırır');
check((await one(`select count(*)::int c from public.topics`)).c === eski, 'rollback yalnızca Maarif konularını siler');
await db.exec(read(migDir, '20261121110000_maarif_curriculum.sql'));
await db.exec(maarifSeed);
check((await one(`select count(*)::int c from public.topics where curriculum = 'maarif'`)).c === total, 're-apply çalışır');

if (failures) { console.log(`\n${failures} test BAŞARISIZ`); process.exit(1); }
console.log('\nTüm Maarif müfredat testleri geçti');
