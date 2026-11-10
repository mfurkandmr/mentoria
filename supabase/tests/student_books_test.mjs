// Kitap takibi (20261105160000_student_books).
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
const asAnon = () => db.exec(`set role anon; select set_config('request.jwt.claim.sub', '', false);`);
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
  await asUser(student);
  const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, `${name} Veli`,
    { guardian_approval: true });
  return { org, admin, coach, student, parent };
}

const A = await school('Bal Akademi', 'ADMINBK1');
const B = await school('Arı Kurs', 'ADMINBK2');
await asSuper();
const mat = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
const topic = (await one(`select id from public.topics where subject_id = $1 order by sort limit 1`, [mat])).id;
const term = (await one(`select public.current_term() t`)).t;

console.log('Dönem');
const terms = await one(`select public.term_of('2026-09-01') a, public.term_of('2027-01-31') b, public.term_of('2027-02-01') c, public.term_of('2027-08-31') d`);
check(terms.a === '2026-Güz' && terms.b === '2026-Güz' && terms.c === '2027-Bahar' && terms.d === '2027-Bahar', 'Güz Eylül-Ocak, Bahar Şubat-Ağustos', terms);

console.log('Havuz ve talep');
await asUser(A.admin);
const pool = [];
for (let i = 1; i <= 10; i++) {
  pool.push((await one(`insert into public.books (name, publisher, subject_id) values ($1, '3D Yayınları', $2) returning *`, [`TYT Matematik Soru Bankası ${i}`, mat])));
}
check(pool[0].status === 'active' && pool[0].org_id === A.org, 'müdür havuza aktif ekler');
await expectError('aynı ad + yayın (yazım farkıyla) tekrar eklenemez', () =>
  db.query(`insert into public.books (name, publisher) values ('tyt matematik soru bankasi 1', '3d yayinlari')`), 'unique');

await asUser(A.student);
const req = await one(`insert into public.books (name, publisher, subject_id, status) values ('Karekök Paragraf', 'Karekök', $1, 'active') returning *`, [mat]);
check(req.status === 'pending' && req.requested_by === A.student, 'öğrenci yalnızca talep oluşturur (durum zorla bekliyor)', req);
await expectError('talep edilen kitap onaysız öğrencinin listesine eklenemez', () =>
  db.query(`insert into public.student_books (student_id, book_id) values ($1, $2)`, [A.student, req.id]), 'BOOK_NOT_IN_POOL');
await expectError('başka kurumun kitabı eklenemez', async () => {
  await asUser(B.admin);
  const other = await one(`insert into public.books (name, publisher) values ('Başka Kitap', 'X') returning id`);
  await asUser(A.student);
  await db.query(`insert into public.student_books (student_id, book_id) values ($1, $2)`, [A.student, other.id]);
}, 'BOOK_NOT_IN_POOL');
await asUser(A.student);
check((await rows(`select id from public.books where status = 'pending'`)).length === 1, 'öğrenci kendi talebini görür');
await asUser(A.parent);
check((await rows(`select id from public.books where status = 'pending'`)).length === 0, 'veli bekleyen talebi görmez');
await expectError('veli kitap ekleyemez', () =>
  db.query(`insert into public.books (name, publisher) values ('Veli Kitabı', 'X')`), 'NOT_ALLOWED');

await asUser(A.coach);
await db.query(`select public.approve_book($1)`, [req.id]);
await asSuper();
const note = await one(`select data from public.notifications where user_id = $1 and kind = 'book_request'`, [A.student]);
check(note?.data.result === 'approved' && note.data.book === 'Karekök Paragraf', 'onaylanınca öğrenciye bildirim', note);
check((await one(`select status from public.books where id = $1`, [req.id])).status === 'active', 'talep havuza girdi');

await asUser(A.student);
const dup = await one(`insert into public.books (name, publisher) values ('Toprak TYT Deneme', 'Toprak') returning id`);
const rej = await one(`insert into public.books (name, publisher) values ('Uydurma Kitap', 'Yok') returning id`);
await asUser(A.admin);
await db.query(`select public.merge_book_request($1, $2)`, [dup.id, pool[1].id]);
await db.query(`select public.reject_book_request($1, 'Kurumda kullanılmıyor')`, [rej.id]);
await asSuper();
const res = await rows(`select data from public.notifications where user_id = $1 and kind = 'book_request' order by created_at`, [A.student]);
check(res.length === 3 && res[1].data.book === pool[1].name && res[2].data.result === 'rejected', 'birleştir ve reddet bildirimleri', res.map((r) => r.data));
await asUser(A.student);
await expectError('öğrenci talebi onaylayamaz', () => db.query(`select public.approve_book($1)`, [pool[0].id]), 'NOT_ALLOWED');

console.log('Dönem sınırı');
await asUser(A.student);
const mine = [];
for (let i = 0; i < 7; i++) {
  mine.push(await one(`insert into public.student_books (student_id, book_id, status) values ($1, $2, 'finished') returning *`, [A.student, pool[i].id]));
}
check(mine[0].term === term && mine[0].status === 'active' && mine[0].added_role === 'student', 'öğrenci ekler (dönem sunucuda, durum devam)', mine[0]);
await expectError('7 kitaptan sonra 8. eklenemez', () =>
  db.query(`insert into public.student_books (student_id, book_id) values ($1, $2)`, [A.student, pool[7].id]), 'BOOK_LIMIT');
let upd = await db.query(`update public.student_books set status = 'finished' where id = $1`, [mine[0].id]);
check(upd.affectedRows === 0, 'öğrenci kitabının durumunu değiştiremez');
upd = await db.query(`delete from public.student_books where id = $1`, [mine[0].id]);
check(upd.affectedRows === 0, 'öğrenci kitabını silemez');

await asUser(A.coach);
upd = await db.query(`update public.student_books set status = 'finished' where id = $1`, [mine[0].id]);
check(upd.affectedRows === 1, 'koç durumu "bitti" yapar');
await expectError('"bitti" işaretlenen kitap sınırı boşaltmaz', () =>
  db.query(`insert into public.student_books (student_id, book_id) values ($1, $2)`, [A.student, pool[7].id]), 'BOOK_LIMIT');
await db.query(`delete from public.student_books where id = $1`, [mine[6].id]);
let ov = (await one(`select public.student_books_overview($1) o`, [A.student])).o;
check(ov.used === 6 && ov.limit === 7, 'koç silince sınırdan düşer', ov);
await db.query(`insert into public.student_books (student_id, book_id) values ($1, $2)`, [A.student, pool[6].id]);
await expectError('koç da sınırı aşamaz', () =>
  db.query(`insert into public.student_books (student_id, book_id) values ($1, $2)`, [A.student, pool[7].id]), 'BOOK_LIMIT');
await db.query(`select public.set_book_limit($1, 9, 'Ek deneme kitapları')`, [A.student]);
await asUser(A.student);
await db.query(`insert into public.student_books (student_id, book_id) values ($1, $2)`, [A.student, pool[7].id]);
ov = (await one(`select public.student_books_overview($1) o`, [A.student])).o;
check(ov.used === 8 && ov.limit === 9 && ov.books.length === 8, 'sınır 9 olunca 8. kitap eklenir', { used: ov.used, limit: ov.limit });
await expectError('öğrenci sınırı değiştiremez', () =>
  db.query(`select public.set_book_limit($1, 20, 'x')`, [A.student]), 'NOT_ALLOWED');

console.log('Çalışma kaydı');
const sb = mine[1].id;
const p1 = await one(`insert into public.book_progress (student_book_id, topic_id, page_from, page_to, questions, correct, wrong, blank)
  values ($1, $2, 10, 20, 40, 30, 6, 4) returning id`, [sb, topic]).then((r) => one(`select * from public.book_progress where id = $1`, [r.id]));
check(p1.student_id === A.student && p1.entered_role === 'student' && p1.question_log_id, 'öğrenci çalışma ekler, soru kaydına yansır', p1);
const ql = await one(`select * from public.question_logs where id = $1`, [p1.question_log_id]);
check(ql.correct === 30 && ql.wrong === 6 && ql.blank === 4 && ql.subject_id === mat && ql.source.includes('3D Yayınları'),
  'question_logs: doğru/yanlış/boş ve kaynak kitap', ql);
await expectError('doğru+yanlış+boş > soru sayısı reddedilir', () =>
  db.query(`insert into public.book_progress (student_book_id, questions, correct, wrong, blank) values ($1, 10, 8, 2, 1)`, [sb]), 'check');
await expectError('bitiş sayfası başlangıçtan küçük olamaz', () =>
  db.query(`insert into public.book_progress (student_book_id, page_from, page_to) values ($1, 20, 10)`, [sb]), 'check');
await expectError('ileri tarih olamaz', () =>
  db.query(`insert into public.book_progress (student_book_id, studied_on) values ($1, current_date + 2)`, [sb]), 'BOOK_FUTURE_DATE');
upd = await db.query(`update public.book_progress set correct = 32, wrong = 4 where id = $1`, [p1.id]);
check(upd.affectedRows === 1, 'öğrenci 24 saat içinde düzenler');
const ql2 = await one(`select q.correct from public.book_progress p join public.question_logs q on q.id = p.question_log_id where p.id = $1`, [p1.id]);
check(ql2.correct === 32, 'düzenleme soru kaydına yansır', ql2);
check((await one(`select count(*)::int c from public.question_logs where student_id = $1`, [A.student])).c === 1, 'eski yansıma silindi');
await asSuper();
await db.exec(`alter table public.book_progress disable trigger guard_book_progress`);
await db.query(`update public.book_progress set created_at = now() - interval '25 hours' where id = $1`, [p1.id]);
await db.exec(`alter table public.book_progress enable trigger guard_book_progress`);
await asUser(A.student);
upd = await db.query(`update public.book_progress set note = 'geç' where id = $1`, [p1.id]);
check(upd.affectedRows === 0, '24 saatten sonra öğrenci düzenleyemez');
upd = await db.query(`delete from public.book_progress where id = $1`, [p1.id]);
check(upd.affectedRows === 0, '24 saatten sonra öğrenci silemez');
await asUser(A.coach);
upd = await db.query(`update public.book_progress set note = 'koç düzeltti' where id = $1`, [p1.id]);
check(upd.affectedRows === 1, 'koç her zaman düzenler');

console.log('Veli salt okunur');
await asUser(A.parent);
check((await rows(`select id from public.student_books`)).length === 8, 'veli çocuğunun kitaplarını görür');
check((await rows(`select id from public.book_progress`)).length === 1, 'veli çalışmaları görür');
check((await one(`select public.student_books_overview($1) o`, [A.student])).o.used === 8, 'veli özeti görür');
await expectError('veli kitap ekleyemez', () =>
  db.query(`insert into public.student_books (student_id, book_id) values ($1, $2)`, [A.student, pool[8].id]), 'NOT_ALLOWED');
await expectError('veli çalışma ekleyemez', () =>
  db.query(`insert into public.book_progress (student_book_id) values ($1)`, [sb]), 'NOT_ALLOWED');
upd = await db.query(`update public.book_progress set note = 'veli' where id = $1`, [p1.id]);
check(upd.affectedRows === 0, 'veli düzenleyemez');

console.log('Yalıtım ve özetler');
await asUser(B.coach);
check((await rows(`select id from public.student_books`)).length === 0, 'öteki kurumun koçu kitapları görmez');
await expectError('öteki koç özeti göremez', () => db.query(`select public.student_books_overview($1)`, [A.student]), 'NOT_ALLOWED');
check((await rows(`select id from public.books`)).every((b) => true) && (await rows(`select id from public.books where name like 'TYT%'`)).length === 0,
  'öteki kurum havuzu görmez');
await asUser(A.admin);
const usage = await rows(`select * from public.book_usage()`);
check(usage.find((u) => u.book_id === pool[1].id)?.total_questions === 40, 'kitap kullanımı', usage);

console.log('Konu boşluğu sinyali');
await asSuper();
const exam = await one(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'D1') returning id`, [A.student]);
const topic2 = (await one(`select id from public.topics where subject_id = $1 and id <> $2 order by sort limit 1`, [mat, topic])).id;
for (let q = 1; q <= 4; q++) {
  await db.query(`insert into public.exam_answers (exam_id, subject_id, question_no, marked, correct, topic_id) values ($1, $2, $3, $4, 'A', $5)`,
    [exam.id, mat, q, q === 1 ? 'A' : 'B', topic2]);
  await db.query(`insert into public.exam_answers (exam_id, subject_id, question_no, marked, correct, topic_id) values ($1, $2, $3, 'B', 'A', $4)`,
    [exam.id, mat, q + 10, topic]);
}
await asUser(A.coach);
const gaps = await rows(`select * from public.topic_gaps($1)`, [A.student]);
check(gaps.length === 1 && gaps[0].topic_id === topic2 && gaps[0].rate === 25,
  'başarısı düşük ve kitapla çalışılmamış konu (çalışılan konu listede yok)', gaps);

console.log('Havuz içe aktarma');
await asUser(A.admin);
const imp = (await one(`select public.import_books($1) r`, [JSON.stringify([
  { name: 'Yeni Kitap', publisher: 'Palme', subject_id: mat, kind: 'lecture' },
  { name: 'tyt matematik soru bankası 1', publisher: '3D YAYINLARI' },
])])).r;
check(imp.inserted === 1 && imp.skipped === 1, 'içe aktarmada mükerrer atlanır', imp);

console.log('Kitap raporu (kim hangi kitaptan kaç soru çözdü)');
await asSuper();
const aytMat = (await one(`select id from public.subjects where code = 'AYT_MAT'`)).id;
await asUser(A.admin);
const lim = await one(`select count(*)::int c from public.student_books where student_id = $1 and term = $2`, [A.student, term]);
await db.query(`select public.set_book_limit($1, $2, 'rapor testi')`, [A.student, lim.c + 2]);
const rb = await one(`insert into public.books (name, publisher, subject_id) values ('3-4-5 AYT Matematik', '3-4-5 Yayınları', $1) returning id`, [aytMat]);
const rsb = await one(`insert into public.student_books (student_id, book_id) values ($1, $2) returning id`, [A.student, rb.id]);
await db.query(`insert into public.book_progress (student_book_id, questions, correct, wrong, blank) values ($1, 200, 150, 30, 20), ($1, 39, 30, 5, 4)`, [rsb.id]);
const rb2 = await one(`insert into public.books (name, publisher) values ('Hiç çözülmeyen', 'Yayın') returning id`);
await db.query(`insert into public.student_books (student_id, book_id) values ($1, $2)`, [A.student, rb2.id]);
const report = await rows(`select * from public.book_question_report()`);
const row = report.find((r) => r.book_id === rb.id);
check(row && row.questions === 239 && row.correct === 180 && row.wrong === 35 && row.blank === 24 && row.subject_code === 'AYT_MAT'
  && row.student_name === 'Bal Akademi Öğrenci', 'müdür öğrenci ve kitap başına soruyu görür', row);
check(report.find((r) => r.book_id === rb2.id)?.questions === 0, 'çözülmeyen kitap 0 soru');
check((await rows(`select * from public.book_question_report('2020-Güz')`)).length === 0, 'dönem süzgeci çalışır');
await asUser(A.coach);
check((await rows(`select * from public.book_question_report()`)).some((r) => r.book_id === rb.id), 'koç kendi öğrencisini görür');
await asUser(B.admin);
check((await rows(`select * from public.book_question_report()`)).every((r) => r.student_id !== A.student), 'başka kurumun müdürü görmez');
await asUser(B.coach);
check((await rows(`select * from public.book_question_report()`)).every((r) => r.student_id !== A.student), 'başka kurumun koçu görmez');
await asUser(A.student);
check((await rows(`select * from public.book_question_report()`)).length === 0, 'öğrenciye boş döner');
await asUser(A.parent);
check((await rows(`select * from public.book_question_report()`)).length === 0, 'veliye boş döner');
await asAnon();
await expectError('anonim çağıramaz', () => db.query(`select * from public.book_question_report()`), 'permission');

console.log('Geri alma ve yeniden uygulama');
await asSuper();
const name = '20261105160000_student_books';
const later = migs.filter((f) => f > `${name}.sql`).map((f) => f.replace('.sql', '')).reverse();
for (const l of later) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.books') t`)).t === null, 'tablolar kaldırıldı');
check((await one(`select count(*)::int c from public.question_logs where student_id = $1`, [A.student])).c === 0, 'yansıyan soru kayıtları silindi');
await db.exec(read(migDir, `${name}.sql`));
for (const l of [...later].reverse()) await db.exec(read(migDir, `${l}.sql`));
check((await one(`select to_regclass('public.books') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
