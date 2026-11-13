// Kurum sınavı içe aktarma: AYT (alan dışı test sayılmaz, alan türetilir) ve YDT.
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';

const root = process.argv[2] ?? '../..';
const migDir = `${root}/supabase/migrations`;
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
const rows = async (sql, p = []) => (await db.query(sql, p)).rows;
async function expectError(n, fn, pattern) {
  try { await fn(); bad(n, 'hata bekleniyordu'); }
  catch (e) { (!pattern || e.message.includes(pattern)) ? ok(n) : bad(n, e.message); }
}
async function signUp(code, name, meta = {}) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true,
      privacy_version: '1.0', ...meta })])).id;
}
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const sCode = (await one(`select public.create_invite('student', null, 5) c`)).c;
  const student = await signUp(sCode, `${name} Öğrenci`);
  const student2 = await signUp(sCode, `${name} Öğrenci İki`);
  return { org, admin, coach, student, student2 };
}

const A = await school('Bal Akademi', 'ADMINAY1');
await asSuper();
const ids = {};
for (const c of ['AYT_EDB', 'AYT_TAR1', 'AYT_COG1', 'AYT_TAR2', 'AYT_MAT', 'AYT_FIZ', 'YDT_YD']) {
  ids[c] = (await one(`select id from public.subjects where code = $1`, [c])).id;
}

const results = async (key, student) => {
  await asSuper();
  const e = await one(`select * from public.exams where batch_id = $1 and student_id = $2`, [key, student]);
  if (!e) return { e: null, subj: {} };
  const subj = Object.fromEntries((await rows(`select * from public.exam_subject_results where exam_id = $1`, [e.id]))
    .map((r) => [r.subject_id, r]));
  return { e, subj };
};
const importAndPublish = async (key, sheets) => {
  await asUser(A.admin);
  const imp = (await one(`select public.start_exam_import($1, 'optik.txt', '{}') id`, [key])).id;
  const res = (await one(`select public.import_exam_sheets($1, $2) r`, [imp, JSON.stringify(sheets)])).r;
  await db.query(`select public.finish_exam_import($1)`, [imp]);
  const n = (await one(`select public.publish_exam($1) n`, [key])).n;
  return { res, n };
};
const blank = (n) => Array(n).fill(null);

console.log('AYT');
// Dersler kitapçık sırasıyla: Edebiyat-Sosyal-1, Sosyal-2, Matematik, Fen.
const aytSubjects = [['AYT_EDB', 2], ['AYT_TAR1', 2], ['AYT_COG1', 1], ['AYT_TAR2', 1], ['AYT_MAT', 3], ['AYT_FIZ', 2]];
const aytDef = JSON.stringify({
  name: 'AYT Kurum Denemesi 1', exam_type: 'AYT', kind: 'deneme', taken_on: '2026-11-15',
  wrong_penalty: true, penalty_ratio: 0.25, classrooms: [],
  subjects: aytSubjects.map(([subject, count]) => ({ subject, count, weight: 1 })),
  items: aytSubjects.flatMap(([subject, count]) => Array.from({ length: count }, (_, i) =>
    ({ subject, no: i + 1, correct: 'A', outcome: `${subject} kazanım` }))),
  // B kitapçığında matematik ters sırada, A'nın 1. sorusunun şıkkı da değişik.
  booklets: { B: [{ subject: 'AYT_MAT', no: 1, item_no: 3 }, { subject: 'AYT_MAT', no: 2, item_no: 2 },
    { subject: 'AYT_MAT', no: 3, item_no: 1, correct: 'E' }] },
});
await asUser(A.coach);
const ayt = (await one(`select public.save_exam(null, $1) id`, [aytDef])).id;
await asSuper();
const order = (await rows(`select s.code from public.answer_key_subjects ks join public.subjects s on s.id = ks.subject_id
  where ks.key_id = $1 order by ks.sort`, [ayt])).map((r) => r.code);
check(order.join() === aytSubjects.map((s) => s[0]).join(), 'ders sırası kaydedildiği gibi (kitapçık sırası)', order);

// Sayısal: yalnızca Matematik + Fizik. Öbür testlerin dizisi boş gelir.
const saySheet = { AYT_EDB: blank(2), AYT_TAR1: blank(2), AYT_COG1: blank(1), AYT_TAR2: blank(1),
  AYT_MAT: ['A', 'B', null], AYT_FIZ: ['A', 'A'] };
// Sözel: Edebiyat, Tarih-1, Tarih-2; Matematik'e dokunmadı.
const sozSheet = { AYT_EDB: ['A', 'C'], AYT_TAR1: ['a', null], AYT_COG1: blank(1), AYT_TAR2: ['B'],
  AYT_MAT: blank(3), AYT_FIZ: blank(2) };
const a1 = await importAndPublish(ayt, [
  { student_id: A.student, booklet: 'A', answers: saySheet },
  { student_id: A.student2, booklet: 'B', answers: sozSheet },
]);
check(a1.res.saved === 2 && a1.n === 2, 'iki AYT optiği kaydedildi ve puanlandı', a1);
let s1 = await results(ayt, A.student);
let s2 = await results(ayt, A.student2);
check(s1.e.exam_type === 'AYT' && s1.e.field === 'SAY', 'Fizik işaretleyen öğrencinin alanı Sayısal', s1.e);
check(Object.keys(s1.subj).length === 2, 'sayısal: yalnızca işaretlediği iki ders sayılır', Object.keys(s1.subj));
check(s1.subj[ids.AYT_MAT].correct === 1 && s1.subj[ids.AYT_MAT].wrong === 1 && s1.subj[ids.AYT_MAT].blank === 1
  && Number(s1.subj[ids.AYT_MAT].net) === 0.75, 'Matematik 1D 1Y 1B = 0,75', s1.subj[ids.AYT_MAT]);
check(Number(s1.subj[ids.AYT_FIZ].net) === 2 && Number(s1.e.total_net) === 2.75, 'toplam net 2,75', s1.e.total_net);
check(s1.subj[ids.AYT_EDB] === undefined, 'işaretsiz Edebiyat boş sayılmaz, hiç yazılmaz');
check(s2.e.field === 'SOZ' && s2.e.booklet === 'B', 'Tarih-2 işaretleyen öğrencinin alanı Sözel', s2.e);
check(Object.keys(s2.subj).length === 3 && s2.subj[ids.AYT_MAT] === undefined && s2.subj[ids.AYT_COG1] === undefined,
  'sözel: Matematik ve işaretsiz Coğrafya-1 sayılmaz', Object.keys(s2.subj));
check(s2.subj[ids.AYT_EDB].correct === 1 && s2.subj[ids.AYT_EDB].wrong === 1 && Number(s2.subj[ids.AYT_EDB].net) === 0.75,
  'Edebiyat 1D 1Y', s2.subj[ids.AYT_EDB]);
check(s2.subj[ids.AYT_TAR1].correct === 1 && s2.subj[ids.AYT_TAR1].blank === 1, 'küçük harf işaret doğru sayılır', s2.subj[ids.AYT_TAR1]);
check(Number(s2.subj[ids.AYT_TAR2].net) === -0.25 && Number(s2.e.total_net) === 1.5, 'toplam net 0,75 + 1 − 0,25', s2.e.total_net);
check(Number((await one(`select count(*) n from public.exam_answers where exam_id = $1`, [s1.e.id])).n) === 5,
  'soru soru: yalnızca işaretlenen derslerin soruları');

console.log('AYT: eşit ağırlık, B kitapçığı kendi anahtarıyla');
await asUser(A.admin);
const impEa = (await one(`select public.start_exam_import($1, 'optik.txt', '{}') id`, [ayt])).id;
// B'de 1. sıra = A'nın 3. sorusu (A), 3. sıra = A'nın 1. sorusu (bu kitapçıkta E).
await db.query(`select public.import_exam_sheets($1, $2)`, [impEa, JSON.stringify([
  { student_id: A.student2, booklet: 'B', answers: { AYT_EDB: ['A', 'A'], AYT_TAR1: ['A', 'A'], AYT_COG1: ['A'],
    AYT_MAT: ['A', 'A', 'E'] } }])]);
await db.query(`select public.finish_exam_import($1)`, [impEa]);
s2 = await results(ayt, A.student2);
check(s2.e.field === 'EA', 'Matematik + Edebiyat işaretleyen öğrencinin alanı Eşit Ağırlık', s2.e.field);
check(s2.subj[ids.AYT_MAT].correct === 3 && s2.subj[ids.AYT_TAR2] === undefined && Number(s2.e.total_net) === 8,
  'B kitapçığı kendi sırası ve şıkkıyla; yeniden yüklemede eski dersler silinir', [s2.subj, s2.e.total_net]);

console.log('YDT');
const ydtDef = {
  name: 'YDT Kurum Denemesi 1', exam_type: 'YDT', kind: 'deneme', taken_on: '2026-11-22',
  wrong_penalty: true, penalty_ratio: 0.25, classrooms: [],
  subjects: [{ subject: 'YDT_YD', count: 80, weight: 1 }],
  items: Array.from({ length: 80 }, (_, i) => ({ subject: 'YDT_YD', no: i + 1, correct: 'ABCDE'[i % 5], outcome: 'Okuma' })),
  booklets: {},
};
await asUser(A.coach);
await expectError('YDT sınavına AYT dersi eklenemez', () => db.query(`select public.save_exam(null, $1)`,
  [JSON.stringify({ ...ydtDef, subjects: [{ subject: 'AYT_MAT', count: 5 }], items: [] })]), 'INVALID_SUBJECTS');
const ydt = (await one(`select public.save_exam(null, $1) id`, [JSON.stringify(ydtDef)])).id;
// 50 doğru, 20 yanlış, 10 boş.
const ydSheet = Array.from({ length: 80 }, (_, i) => (i < 50 ? 'ABCDE'[i % 5] : i < 70 ? 'ABCDE'[(i + 1) % 5] : null));
const y1 = await importAndPublish(ydt, [
  { student_id: A.student, booklet: 'A', answers: { YDT_YD: ydSheet } },
  { student_id: A.student2, booklet: '', answers: { YDT_YD: blank(80) } },
]);
check(y1.res.saved === 2 && y1.n === 2, 'iki YDT optiği kaydedildi', y1);
s1 = await results(ydt, A.student);
const yd = s1.subj[ids.YDT_YD];
check(s1.e.exam_type === 'YDT' && s1.e.field === 'DIL', 'YDT alanı Dil', s1.e);
check(yd.correct === 50 && yd.wrong === 20 && yd.blank === 10 && Number(yd.net) === 45 && Number(s1.e.total_net) === 45,
  'YDT 50D 20Y 10B = 45 net', yd);
s2 = await results(ydt, A.student2);
check(s2.e !== null && Object.keys(s2.subj).length === 0 && Number(s2.e.total_net ?? 0) === 0,
  'boş YDT kağıdı: deneme var, ders sonucu yok', s2);
await asUser(A.student);
check((await rows(`select 1 from public.exams where batch_id in ($1, $2)`, [ayt, ydt])).length === 2,
  'öğrenci AYT ve YDT sonucunu görür');

console.log(failures === 0 ? '\nTüm testler geçti.' : `\n${failures} test başarısız.`);
process.exit(failures === 0 ? 0 : 1);
