// Optik okuma (20261030100000_optic_reading): cevap anahtarı + kazanımlar,
// optiğin sunucuda değerlendirilmesi, yetkiler, yeniden okuma, kilit.
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
const b = await school('Bulut', 'BULUT-ADMIN');
const other = await coachIn(b.admin, 'Bulut Koç');
const can = await signUp(other.code, 'Can');

await asSuper();
const trig = (await one(`select t.id from public.topics t join public.subjects s on s.id = t.subject_id
                         where s.code = 'TYT_MAT' order by t.id limit 1`)).id;
const fizTopic = (await one(`select t.id from public.topics t join public.subjects s on s.id = t.subject_id
                             where s.code = 'TYT_FIZ' order by t.id limit 1`)).id;

const items = [
  { subject: 'TYT_MAT', no: 1, correct: 'C', outcome: 'Trigonometri', topic_id: trig },
  { subject: 'TYT_MAT', no: 2, correct: 'a', outcome: 'Üslü sayılar' },
  { subject: 'TYT_MAT', no: 3, correct: '', outcome: 'İptal edilen soru' },
  { subject: 'TYT_TUR', no: 1, correct: 'B', outcome: 'Sözcükte anlam' },
  // Başka dersin konusu bağlanmaz.
  { subject: 'TYT_TUR', no: 2, correct: 'D', outcome: 'Paragraf', topic_id: fizTopic },
];
const createKey = (list, type = 'TYT') => db.query(
  `select public.create_answer_key('Kasım TYT-1', $1, 'Yayın A', '2026-11-01', 'mentoria_yks', $2) id`,
  [type, JSON.stringify(list)]).then((r) => r.rows[0].id);

// --- Anahtar ---------------------------------------------------------------------
await asUser(ali);
await expectError('öğrenci anahtar oluşturamaz', () => createKey(items), 'NOT_ALLOWED');
await asUser(coach.id);
await expectError('TYT anahtarına AYT dersi giremez', () => createKey([{ subject: 'AYT_FIZ', no: 1, correct: 'A' }]), 'INVALID_ITEMS');
await expectError('soru no ders soru sayısını aşamaz', () => createKey([{ subject: 'TYT_FIZ', no: 8, correct: 'A' }]), 'INVALID_ITEMS');
await expectError('boş anahtar olmaz', () => createKey([]), 'NO_ITEMS');
await expectError('koç anahtara doğrudan yazamaz',
  () => db.query(`insert into public.answer_keys (tenant_id, org_id, name, exam_type, template_id)
                  select tenant_id, $1, 'x', 'TYT', 'a' from public.organizations where id = $1`, [a.org]), 'permission');
const key = await createKey(items);
check(!!key, 'koç anahtar oluşturdu');
let rows = await all(`select s.code, k.question_no, k.correct, k.topic_id from public.answer_key_items k
                      join public.subjects s on s.id = k.subject_id order by s.code, k.question_no`);
check(rows.length === 5, '5 soru kaydedildi', rows);
check(rows.find((r) => r.code === 'TYT_MAT' && r.question_no === 2).correct === 'A', 'cevap büyük harfe çevrildi');
check(rows.find((r) => r.code === 'TYT_MAT' && r.question_no === 3).correct === null, 'boş cevap iptal soru');
check(rows.find((r) => r.code === 'TYT_TUR' && r.question_no === 2).topic_id === null, 'başka dersin konusu bağlanmadı');

await asUser(a.admin);
check((await all(`select id from public.answer_keys`)).length === 1, 'kurum müdürü anahtarı görür');
await asUser(other.id);
check((await all(`select id from public.answer_keys`)).length === 0, 'başka kurumun koçu görmez');
check((await all(`select key_id from public.answer_key_items`)).length === 0, 'başka kurumun koçu kazanımları görmez');
await asUser(ali);
check((await all(`select id from public.answer_keys`)).length === 0, 'öğrenci anahtarı (cevapları) görmez');

// --- Optik ------------------------------------------------------------------------
const submit = (student, answers, k = key) =>
  db.query(`select public.submit_optic($1, $2, $3) r`, [k, student, JSON.stringify(answers)]).then((r) => r.rows[0].r);

await asUser(other.id);
await expectError('başka kurumun koçu bu anahtarla okuyamaz', () => submit(can, { TYT_MAT: ['C'] }), 'KEY_NOT_FOUND');
await asUser(coach.id);
await expectError('başka kurumun öğrencisine yazılamaz', () => submit(can, { TYT_MAT: ['C'] }), 'NOT_ALLOWED');

let r = await submit(ali, { TYT_MAT: ['C', 'b', 'D', 'E'], TYT_TUR: [null, 'X'] });
check(r.correct === 1 && r.wrong === 1 && r.blank === 2 && Number(r.net) === 0.75 && r.updated === false,
  'Ali: Mat 1D 1Y (iptal sayılmaz), Türkçe 2B (geçersiz işaret boş)', r);
const aliExam = r.exam_id;
await asSuper();
let ex = await one(`select source, batch_id, name, exam_type, publisher, taken_on::text d, created_by from public.exams where id = $1`, [aliExam]);
check(ex.source === 'optic' && ex.batch_id === key && ex.name === 'Kasım TYT-1' && ex.publisher === 'Yayın A'
  && ex.d === '2026-11-01' && ex.created_by === coach.id, 'deneme anahtarın bilgileriyle yazıldı', ex);
rows = await all(`select s.code, r.correct, r.wrong, r.blank from public.exam_subject_results r
                  join public.subjects s on s.id = r.subject_id where r.exam_id = $1 order by s.code`, [aliExam]);
check(JSON.stringify(rows) === JSON.stringify([
  { code: 'TYT_MAT', correct: 1, wrong: 1, blank: 0 },
  { code: 'TYT_TUR', correct: 0, wrong: 0, blank: 2 },
]), 'ders sonuçları', rows);
rows = await all(`select topic_id, count from public.exam_wrong_topics where exam_id = $1`, [aliExam]);
check(rows.length === 0, 'Trigonometri doğru: yanlış konu yok', rows);
check(Number((await one(`select count(*) n from public.notifications where user_id = $1 and kind = 'exam'`, [ali])).n) === 1,
  'Ali\'ye "deneme sonucun geldi" bildirimi');

// Ali kendi cevaplarını ve kazanımları görür; Ayşe göremez.
await asUser(ali);
rows = await all(`select s.code, a.question_no, a.marked, a.correct, a.outcome from public.exam_answers a
                  join public.subjects s on s.id = a.subject_id order by s.code, a.question_no`);
check(rows.length === 5, 'Ali 5 sorunun cevabını görür', rows);
const mat2 = rows.find((x) => x.code === 'TYT_MAT' && x.question_no === 2);
check(mat2.marked === 'B' && mat2.correct === 'A' && mat2.outcome === 'Üslü sayılar', 'Mat 2: B işaretledi, doğru A, kazanım', mat2);
check(rows.find((x) => x.code === 'TYT_TUR' && x.question_no === 2).marked === null, 'geçersiz işaret boş sayıldı');
await asUser(ayse);
check((await all(`select 1 from public.exam_answers`)).length === 0, 'Ayşe, Ali\'nin cevaplarını görmez');

// Yeniden okuma: deneme yerinde güncellenir, bildirim tekrar gitmez.
await asUser(coach.id);
r = await submit(ali, { TYT_MAT: ['A', 'A'], TYT_TUR: ['B', 'D'] });
check(r.updated === true && r.exam_id === aliExam && r.correct === 3 && r.wrong === 1, 'yeniden okundu, aynı deneme güncellendi', r);
await asSuper();
check(Number((await one(`select count(*) n from public.exams where batch_id = $1 and student_id = $2`, [key, ali])).n) === 1, 'tek deneme');
check(Number((await one(`select count(*) n from public.notifications where user_id = $1 and kind = 'exam'`, [ali])).n) === 1, 'bildirim tekrar gitmedi');
rows = await all(`select topic_id, count from public.exam_wrong_topics where exam_id = $1`, [aliExam]);
check(rows.length === 1 && rows[0].topic_id === trig && rows[0].count === 1, 'yanlış kazanım konu takibine yazıldı', rows);

// Ayşe: hiç işaret yok → TYT'de tüm sorular boş sayılır.
await asUser(coach.id);
r = await submit(ayse, {});
check(r.blank === 4 && r.correct === 0, 'boş optik: 4 boş (iptal hariç)', r);

// Kurum müdürü de okuyabilir; denemeler ekranında tek paket.
await asUser(a.admin);
rows = await all(`select student_count from public.my_exam_batches()`);
check(rows.length === 0, 'müdürün kendi yüklemesi yok');
await asUser(coach.id);
rows = await all(`select batch_id, student_count, source from public.my_exam_batches()`);
check(rows.length === 1 && rows[0].batch_id === key && rows[0].student_count === 2 && rows[0].source === 'optic',
  'koçun denemeler ekranında tek paket (2 öğrenci)', rows);

// Kilit: 7 günden eski deneme yeniden okunamaz.
await asSuper();
await db.query(`update public.exams set created_at = now() - interval '8 days' where id = $1`, [aliExam]);
await asUser(coach.id);
await expectError('7 günden eski deneme yeniden okunamaz', () => submit(ali, { TYT_MAT: ['C'] }), 'EXAM_LOCKED');

// AYT: yalnızca işaret konan testler sayılır, alan tahmin edilir.
const aytKey = await db.query(
  `select public.create_answer_key('Kasım AYT-1', 'AYT', null, null, 'mentoria_yks', $1) id`,
  [JSON.stringify([
    { subject: 'AYT_MAT', no: 1, correct: 'A' },
    { subject: 'AYT_FIZ', no: 1, correct: 'B' },
    { subject: 'AYT_EDB', no: 1, correct: 'C' },
  ])]).then((x) => x.rows[0].id);
r = await submit(ayse, { AYT_MAT: ['A'], AYT_FIZ: ['C'] }, aytKey);
await asSuper();
ex = await one(`select field from public.exams where id = $1`, [r.exam_id]);
rows = await all(`select s.code from public.exam_answers a join public.subjects s on s.id = a.subject_id where a.exam_id = $1 order by 1`, [r.exam_id]);
check(ex.field === 'SAY' && rows.map((x) => x.code).join() === 'AYT_FIZ,AYT_MAT', 'AYT: alan SAY, boş Edebiyat sayılmadı', { ex, rows });

// Anahtar silinir, okunmuş denemeler kalır; yalnızca oluşturan siler.
await asUser(a.admin);
await expectError('başkasının anahtarını silemez', () => db.query(`select public.delete_answer_key($1)`, [key]), 'KEY_NOT_FOUND');
await asUser(coach.id);
await db.query(`select public.delete_answer_key($1)`, [key]);
await asSuper();
check(!(await one(`select 1 x from public.answer_keys where id = $1`, [key])), 'anahtar silindi');
check(Number((await one(`select count(*) n from public.exams where batch_id = $1`, [key])).n) === 2, 'okunmuş denemeler duruyor');

// --- Geri alma / yeniden uygulama ----------------------------------------------------
const name = '20261030100000_optic_reading';
// Bu migration'a bağlı sonraki migration'lar önce geri alınır.
const laterDeps = ['20261105170000_exam_import', '20261030110000_optic_booklets'].filter((n) => migs.includes(`${n}.sql`));
for (const l of laterDeps) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.exam_answers') t`)).t === null, 'geri alındı');
check(Number((await one(`select count(*) n from public.exams where source = 'optic'`)).n) === 0, 'optik denemeler import sayıldı');
await db.exec(read(migDir, `${name}.sql`));
for (const l of [...laterDeps].reverse()) await db.exec(read(migDir, `${l}.sql`));
check((await one(`select to_regclass('public.answer_keys') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
