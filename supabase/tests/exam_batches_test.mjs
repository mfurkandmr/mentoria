// Deneme paketleri: listeleme, paketi herkesten silme, 7 günlük kilit,
// bildirim temizliği, yetki ve eski kayıtların paketlere toplanması.
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
const batchMig = migs.find((f) => f.includes('exam_batches'));
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

// Kurum: müdür, iki koç; koç 1'in iki, koç 2'nin bir öğrencisi.
await asSuper();
const org = (await one(`insert into public.organizations (name, seat_limit) values ('Bal Akademi', 20) returning id`)).id;
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMINEB1', $1, 'admin')`, [org]);
const admin = await signUp('ADMINEB1', 'Müdür');
await asUser(admin);
const c1 = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Ayşe Koç');
await asUser(admin);
const c2 = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Burak Koç');
await asUser(c1);
const code1 = (await one(`select public.create_invite('student', null, 10) c`)).c;
const s1 = await signUp(code1, 'Elif Yılmaz');
const s2 = await signUp(code1, 'Can Kaya');
await asUser(c2);
const s3 = await signUp((await one(`select public.create_invite('student', null, 10) c`)).c, 'Zeynep Arslan');

const mat = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
async function exam(coach, student, { name = 'Deneme', batch = null, source = 'manual', correct = 30 } = {}) {
  await asUser(coach);
  const id = (await one(
    `insert into public.exams (student_id, exam_type, name, source, batch_id)
     values ($1, 'TYT', $2, $3, coalesce($4::uuid, gen_random_uuid())) returning id`,
    [student, name, source, batch])).id;
  await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct) values ($1, $2, $3)`, [id, mat, correct]);
  return id;
}

// Koç 1: iki öğrenciye tek Excel yüklemesi + bir elle giriş.
const batch = '11111111-1111-4111-8111-111111111111';
const e1 = await exam(c1, s1, { name: 'Bilgi Sarmal 3', batch, source: 'import', correct: 40 });
const e2 = await exam(c1, s2, { name: 'Bilgi Sarmal 3', batch, source: 'import', correct: 20 });
const manual = await exam(c1, s1, { name: 'Elle deneme' });
const other = await exam(c2, s3, { name: 'Koç 2 denemesi' });

await asSuper();
check((await one(`select count(*)::int c from public.notifications where kind = 'exam' and ref_id = any($1::uuid[])`, [[e1, e2]])).c === 2,
  'yüklemede iki öğrenciye bildirim gitti');

// --- Listeleme
await asUser(c1);
let rows = (await db.query(`select * from public.my_exam_batches()`)).rows;
check(rows.length === 2, 'koç kendi iki paketini görür', rows.map((r) => r.name));
const imp = rows.find((r) => r.batch_id === batch);
check(imp?.student_count === 2 && Number(imp.avg_net) === 30 && imp.source === 'import' && imp.editable === true,
  'Excel paketi: 2 öğrenci, ortalama 30 net, silinebilir', imp);
check(rows[0].name === 'Elle deneme', 'en son girilen paket en üstte', rows.map((r) => r.name));
await asUser(c2);
rows = (await db.query(`select * from public.my_exam_batches()`)).rows;
check(rows.length === 1 && rows[0].name === 'Koç 2 denemesi', 'koç 2 yalnızca kendi yüklemesini görür', rows.map((r) => r.name));
await asUser(s1);
check((await db.query(`select * from public.my_exam_batches()`)).rows.length === 0, 'öğrencinin paket listesi boş');

// --- Yetki
await asUser(c2);
await expectError('başka koçun paketi silinemez', () => db.query(`select public.delete_exam_batch($1)`, [batch]), 'BATCH_NOT_FOUND');
await asUser(admin);
await expectError('müdür, koçun yüklediği paketi bu yolla silemez', () => db.query(`select public.delete_exam_batch($1)`, [batch]), 'BATCH_NOT_FOUND');
await asUser(s1);
await expectError('öğrenci paket silemez', () => db.query(`select public.delete_exam_batch($1)`, [batch]), 'NOT_ALLOWED');

// --- Paketi herkesten sil
await asUser(c1);
const n = (await one(`select public.delete_exam_batch($1) n`, [batch])).n;
check(n === 2, 'paket iki öğrenciden birden silindi', n);
await asSuper();
const left = await one(`select
  (select count(*)::int from public.exams where id = any($1::uuid[])) gone,
  (select count(*)::int from public.exam_subject_results where exam_id = any($1::uuid[])) results,
  (select count(*)::int from public.notifications where kind = 'exam' and ref_id = any($1::uuid[])) notes,
  (select count(*)::int from public.exams where id = any($2::uuid[])) kept`, [[e1, e2], [manual, other]]);
check(left.gone === 0 && left.results === 0, 'denemeler ve sonuçları silindi', left);
check(left.notes === 0, '"Deneme sonucun geldi" bildirimleri de silindi', left);
check(left.kept === 2, 'diğer paketler duruyor', left);
await asUser(c1);
await expectError('silinen paket tekrar silinemez', () => db.query(`select public.delete_exam_batch($1)`, [batch]), 'BATCH_NOT_FOUND');

// --- 7 günlük kilit
await asSuper();
await db.query(`update public.exams set created_at = now() - interval '8 days' where id = $1`, [manual]);
await asUser(c1);
const lockedRow = (await db.query(`select * from public.my_exam_batches()`)).rows.find((r) => r.name === 'Elle deneme');
check(lockedRow?.editable === false, '8 günlük paket kilitli görünür', lockedRow);
const lockedBatch = (await one(`select batch_id from public.exams where id = $1`, [manual])).batch_id;
await expectError('8 günlük paket silinemez', () => db.query(`select public.delete_exam_batch($1)`, [lockedBatch]), 'EXAM_LOCKED');
check((await db.query(`delete from public.exams where id = $1 returning id`, [manual])).rows.length === 0, 'eski deneme doğrudan da silinemez');
check((await db.query(`update public.exams set name = 'x' where id = $1 returning id`, [manual])).rows.length === 0, 'eski deneme düzenlenemez');
check((await db.query(`update public.exam_subject_results set correct = 1 where exam_id = $1 returning exam_id`, [manual])).rows.length === 0, 'eski denemenin sonuçları değiştirilemez');
check((await db.query(`delete from public.exam_subject_results where exam_id = $1 returning exam_id`, [manual])).rows.length === 0, 'eski denemenin sonuçları silinemez');

await asSuper();
await db.query(`update public.exams set created_at = now() - interval '6 days' where id = $1`, [manual]);
await asUser(c1);
check((await db.query(`update public.exams set name = 'Düzeltildi' where id = $1 returning id`, [manual])).rows.length === 1, '6 günlük deneme düzenlenebilir');
check((await one(`select public.delete_exam_batch($1) n`, [lockedBatch])).n === 1, '6 günlük paket silinebilir');

// --- Elle silme (tek deneme) süre içinde çalışır
await asUser(c2);
check((await db.query(`delete from public.exams where id = $1 returning id`, [other])).rows.length === 1, 'yeni deneme tek tek silinebilir');

// --- Geri alma, eski kayıtların paketlenmesi ve yeniden uygulama
await asSuper();
await db.exec(read(rbDir, batchMig.replace('.sql', '.down.sql')));
check((await one(`select count(*)::int c from information_schema.columns where table_name = 'exams' and column_name = 'batch_id'`)).c === 0,
  'geri alma: batch_id kolonu kaldırıldı');
await asUser(c1);
const legacy = [];
for (const s of [s1, s2]) {
  const id = (await one(`insert into public.exams (student_id, exam_type, name, source) values ($1, 'TYT', 'Eski Yükleme', 'import') returning id`, [s])).id;
  legacy.push(id);
}
const legacyManual = (await one(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'Eski Yükleme') returning id`, [s1])).id;
await asSuper();
await db.exec(read(migDir, batchMig));
const b = (await db.query(`select id, batch_id from public.exams where id = any($1::uuid[])`, [[...legacy, legacyManual]])).rows;
const batchOf = (id) => b.find((r) => r.id === id).batch_id;
check(batchOf(legacy[0]) === batchOf(legacy[1]), 'eski Excel yüklemesi tek pakete toplandı', b);
check(batchOf(legacyManual) !== batchOf(legacy[0]), 'elle girilen eski deneme ayrı paket', b);
await asUser(c1);
check((await one(`select count(*)::int c from public.exams where batch_id is null`)).c === 0, 'yeniden uygulama: her denemenin paketi var');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
