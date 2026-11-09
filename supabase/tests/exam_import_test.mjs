// Kurum sınavı: Excel içe aktarma ve kazanım analizi (20261105170000_exam_import).
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
  const student2 = await signUp(sCode, `${name} Öğrenci İki`);
  await asUser(student);
  const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, `${name} Veli`,
    { guardian_approval: true });
  return { org, admin, coach, student, student2, parent };
}

const A = await school('Bal Akademi', 'ADMINEX1');
const B = await school('Arı Kurs', 'ADMINEX2');
await asSuper();
const sid = async (code) => (await one(`select id from public.subjects where code = $1`, [code])).id;
const mat = await sid('TYT_MAT');
const tur = await sid('TYT_TUR');

console.log('Sınıf');
await asUser(A.admin);
const cls = (await one(`insert into public.classrooms (name) values ('12-A') returning id`)).id;
await db.query(`insert into public.classroom_students (classroom_id, student_id) values ($1, $2), ($1, $3)`,
  [cls, A.student, A.student2]);

console.log('Kazanım havuzu');
const o1 = (await one(`insert into public.learning_outcomes (subject_id, name) values ($1, 'Problemler') returning *`, [mat]));
check(o1.org_id === A.org, 'kurum ve tenant tetikleyiciyle dolar', o1);
const o1a = (await one(`insert into public.learning_outcomes (subject_id, parent_id, name, code) values ($1, $2, 'Yaş problemleri', 'M.12.1') returning id`, [mat, o1.id])).id;
const o2 = (await one(`insert into public.learning_outcomes (subject_id, name) values ($1, 'Sayılar') returning id`, [mat])).id;
// outcome_label doğrudan çağrılamaz (20261109130000_security_tighten): sunucu tarafı.
await asSuper();
check((await one(`select public.outcome_label($1) l`, [o1a])).l === 'Problemler — Yaş problemleri', 'etiket: konu — alt konu');
await asUser(A.admin);
await expectError('aynı ad tekrar eklenmez', () =>
  db.query(`insert into public.learning_outcomes (subject_id, name) values ($1, 'PROBLEMLER')`, [mat]), 'learning_outcomes_unique');
const imp1 = (await one(`select public.import_learning_outcomes($1) r`, [JSON.stringify([
  { subject: 'TYT_MAT', topic: 'problemler', subtopic: 'İşçi problemleri' },
  { subject: 'TYT_MAT', topic: 'Problemler', subtopic: 'yaş problemleri' },
  { subject: 'TYT_TUR', topic: 'Paragraf' },
  { subject: 'YOK', topic: 'x' },
])])).r;
check(imp1.inserted === 2 && imp1.skipped === 2, 'toplu ekleme: mükerrer ve tanınmayan ders atlanır', imp1);
await asUser(B.admin);
check((await rows(`select id from public.learning_outcomes`)).length === 0, 'başka kurum kazanımları görmez');
await asUser(A.student);
check((await rows(`select id from public.learning_outcomes`)).length === 0, 'öğrenci havuzu görmez');
await expectError('öğrenci kazanım ekleyemez', () =>
  db.query(`insert into public.learning_outcomes (subject_id, name) values ($1, 'X')`, [mat]));

console.log('Sınav tanımı');
const def = (extra = {}) => JSON.stringify({
  name: 'Kurum Denemesi 1', exam_type: 'TYT', kind: 'deneme', taken_on: '2026-11-01',
  wrong_penalty: true, penalty_ratio: 0.25, classrooms: [cls],
  subjects: [{ subject: 'TYT_MAT', count: 5, weight: 1.5 }, { subject: 'TYT_TUR', count: 4, weight: 1 }],
  items: [
    { subject: 'TYT_MAT', no: 1, correct: 'A', outcome_id: o1a, difficulty: 'easy' },
    { subject: 'TYT_MAT', no: 2, correct: 'B', outcome_id: o1a },
    { subject: 'TYT_MAT', no: 3, correct: 'C', outcome_id: o1a },
    { subject: 'TYT_MAT', no: 4, correct: 'D', outcome_id: o2 },
    { subject: 'TYT_MAT', no: 5, correct: 'E', outcome_id: o2, cancelled: true },
    ...[1, 2, 3, 4].map((no) => ({ subject: 'TYT_TUR', no, correct: 'A', outcome: 'Paragraf' })),
  ],
  // B kitapçığında matematik soruları ters sırada (şıklar aynı).
  booklets: { B: [1, 2, 3, 4, 5].map((no) => ({ subject: 'TYT_MAT', no, item_no: 6 - no })) },
  ...extra,
});
await asUser(A.coach);
const key = (await one(`select public.save_exam(null, $1) id`, [def()])).id;
const k = await one(`select status, kind, wrong_penalty, penalty_ratio from public.answer_keys where id = $1`, [key]);
check(k.status === 'draft' && k.kind === 'deneme', 'yeni sınav taslak', k);
const item1 = await one(`select outcome, outcome_id, difficulty from public.answer_key_items where key_id = $1 and subject_id = $2 and question_no = 1`, [key, mat]);
check(item1.outcome === 'Problemler — Yaş problemleri' && item1.difficulty === 'easy', 'kazanım etiketi soruya yazıldı', item1);
check((await one(`select question_no_b from public.answer_key_items where key_id = $1 and subject_id = $2 and question_no = 1`, [key, mat])).question_no_b === 5,
  'B numarası eski sütuna da yazıldı (kamera akışı)');
await expectError('soru no ders soru sayısını aşamaz', () =>
  db.query(`select public.save_exam(null, $1)`, [def({ items: [{ subject: 'TYT_MAT', no: 6, correct: 'A' }] })]), 'INVALID_ITEMS');
await expectError('ders sınav türünde olmalı', () =>
  db.query(`select public.save_exam(null, $1)`, [def({ subjects: [{ subject: 'AYT_MAT', count: 5 }] })]), 'INVALID_SUBJECTS');
await expectError('kitapçıkta aynı A sorusu iki kez olamaz', () =>
  db.query(`select public.save_exam(null, $1)`, [def({ booklets: { B: [{ subject: 'TYT_MAT', no: 1, item_no: 1 }, { subject: 'TYT_MAT', no: 2, item_no: 1 }] } })]), 'INVALID_BOOKLETS');
await asUser(B.admin);
await expectError('başka kurumun kazanımı kullanılamaz', () =>
  db.query(`select public.save_exam(null, $1)`, [def()]), 'INVALID_ITEMS');
await expectError('başka kurum sınavı düzenleyemez', () =>
  db.query(`select public.save_exam($1, $2)`, [key, def()]), 'KEY_NOT_FOUND');

console.log('Öğrenci anahtarı göremez');
await asUser(A.student);
for (const t of ['answer_keys', 'answer_key_items', 'answer_key_subjects', 'answer_key_booklets', 'exam_sheets', 'exam_imports']) {
  check((await rows(`select 1 from public.${t}`)).length === 0, `öğrenci ${t} okuyamaz`);
}
await expectError('öğrenci içe aktarma başlatamaz', () =>
  db.query(`select public.start_exam_import($1, 'x.xlsx', '{}')`, [key]), 'KEY_NOT_FOUND');
await asAnon();
await expectError('anonim anahtarı okuyamaz', () => db.query(`select * from public.answer_key_items`));

console.log('İçe aktarma (taslak)');
const sheet1 = { TYT_MAT: ['A', 'C', 'C', 'D', 'A'], TYT_TUR: ['A', 'B', null, null] };
const sheet2 = { TYT_MAT: ['E', 'D', 'A', 'A', 'A'] };
await asUser(A.admin);
const imp = (await one(`select public.start_exam_import($1, 'optik.xlsx', $2) id`,
  [key, JSON.stringify({ rows: 5, matched: 3, unmatched: 2, failed: 0, log: { unmatched: ['999'] } })])).id;
const res = (await one(`select public.import_exam_sheets($1, $2) r`, [imp, JSON.stringify([
  { student_id: A.student, booklet: 'A', answers: sheet1 },
  { student_id: A.student2, booklet: 'B', answers: sheet2 },
  { student_id: B.student, booklet: 'A', answers: sheet1 },
  { student_id: A.parent, booklet: 'A', answers: sheet1 },
])])).r;
check(res.saved === 2 && res.skipped.length === 2 && res.skipped.every((s) => s.reason === 'NOT_STUDENT'),
  'başka kurumun öğrencisi ve veli atlanır, içe aktarma durmaz', res);
const res2 = (await one(`select public.import_exam_sheets($1, $2) r`, [imp, JSON.stringify([
  { student_id: A.student, booklet: 'C', answers: sheet1 }])])).r;
check(res2.saved === 0 && res2.skipped[0].reason === 'NO_BOOKLET_KEY', 'anahtarda olmayan kitapçık atlanır', res2);
const fin = (await one(`select public.finish_exam_import($1) r`, [imp])).r;
check(fin.sheets === 2 && fin.published === false, 'taslakta yalnızca ham optik', fin);
check((await rows(`select 1 from public.exams where batch_id = $1`, [key])).length === 0, 'taslakta deneme oluşmaz');
await asUser(A.student);
check((await rows(`select 1 from public.exams where batch_id = $1`, [key])).length === 0, 'öğrenci taslak sonucu görmez');

console.log('Yayınlama ve puanlama');
await asUser(A.coach);
check((await one(`select public.publish_exam($1) n`, [key])).n === 2, 'yayınlanınca 2 optik puanlandı');
await expectError('ikinci kez yayınlanamaz', () => db.query(`select public.publish_exam($1)`, [key]), 'ALREADY_PUBLISHED');
await asSuper();
const res1 = async (student) => {
  const e = await one(`select * from public.exams where batch_id = $1 and student_id = $2`, [key, student]);
  const subj = Object.fromEntries((await rows(`select * from public.exam_subject_results where exam_id = $1`, [e.id]))
    .map((r) => [r.subject_id, r]));
  return { e, subj };
};
let r1 = await res1(A.student);
let r2 = await res1(A.student2);
check(r1.subj[mat].correct === 3 && r1.subj[mat].wrong === 1 && r1.subj[mat].blank === 0 && Number(r1.subj[mat].net) === 2.75,
  'A kitapçığı: iptal soru sayılmaz, net = 3 − 1 × 0,25', r1.subj[mat]);
check(r1.subj[tur].correct === 1 && r1.subj[tur].blank === 2 && Number(r1.subj[tur].net) === 0.75, 'Türkçe 1D 1Y 2B', r1.subj[tur]);
check(Number(r1.e.total_net) === 4.88, 'toplam net katsayıyla: 2,75 × 1,5 + 0,75', r1.e.total_net);
check(r2.subj[mat].correct === 2 && r2.subj[mat].wrong === 2 && Number(r2.subj[mat].net) === 1.5,
  'B kitapçığı kendi sırasıyla doğru puanlandı', r2.subj[mat]);
check(r2.subj[tur].blank === 4 && r2.e.booklet === 'B', 'TYT: işaretsiz ders boş sayılır', r2.subj[tur]);
check(r1.e.rank_org === 1 && r2.e.rank_org === 2 && r1.e.rank_class === 1 && r1.e.classroom_id === cls, 'kurum ve sınıf sıralaması', [r1.e, r2.e]);
check(r1.subj[mat].rank_org === 1 && r2.subj[mat].rank_org === 2, 'ders sıralaması');
const ans = await rows(`select question_no, booklet_no, marked, correct from public.exam_answers where exam_id = $1 and subject_id = $2 order by question_no`, [r2.e.id, mat]);
check(ans[0].booklet_no === 5 && ans[0].marked === 'A' && ans[4].correct === null, 'soru soru: kendi kitapçık numarası, iptal soru boş cevap', ans);
check(Number((await one(`select count(*) n from public.notifications where user_id = $1 and kind = 'exam'`, [A.student])).n) === 1, 'yayınlanınca öğrenciye bildirim');

console.log('Tekrar yükleme');
await asUser(A.admin);
const impB = (await one(`select public.start_exam_import($1, 'optik.xlsx', '{}') id`, [key])).id;
await db.query(`select public.import_exam_sheets($1, $2)`, [impB, JSON.stringify([
  { student_id: A.student, booklet: 'A', answers: { ...sheet1, TYT_TUR: ['A', 'A', 'A', 'A'] } }])]);
await db.query(`select public.finish_exam_import($1)`, [impB]);
await asSuper();
check(Number((await one(`select count(*) n from public.exams where batch_id = $1 and student_id = $2`, [key, A.student])).n) === 1, 'aynı öğrenci için kopya deneme oluşmadı');
check(Number((await one(`select count(*) n from public.exam_sheets where key_id = $1`, [key])).n) === 2, 'ham optik güncellendi');
r1 = await res1(A.student);
check(r1.subj[tur].correct === 4, 'yeni dosyadaki sonuç yazıldı', r1.subj[tur]);
check(Number((await one(`select count(*) n from public.notifications where user_id = $1 and kind = 'exam'`, [A.student])).n) === 1, 'güncellemede bildirim tekrar gitmez');

console.log('Yanlış doğruyu götürmez + yeniden puanlama');
await asUser(A.coach);
await db.query(`select public.save_exam($1, $2)`, [key, def({ wrong_penalty: false })]);
await asSuper();
r1 = await res1(A.student);
check(Number(r1.subj[mat].net) === 3 && Number(r1.subj[mat].wrong_penalty) === 0, 'net = doğru sayısı', r1.subj[mat]);
await asUser(A.coach);
await expectError('sınav türü değişmez', () => db.query(`select public.save_exam($1, $2)`, [key, def({ exam_type: 'AYT', subjects: [{ subject: 'AYT_MAT', count: 5 }], items: [], booklets: {} })]), 'TYPE_LOCKED');
await db.query(`select public.save_exam($1, $2)`, [key, def()]);

console.log('Kazanım analizi');
await asUser(A.student2);
const v2 = await rows(`select * from public.v_student_outcome_analysis where exam_id = $1 order by outcome`, [r2.e.id]);
const yas = v2.find((x) => x.outcome === 'Problemler — Yaş problemleri');
check(yas && yas.questions === 3 && yas.correct === 1 && yas.wrong === 2 && Number(yas.success_pct) === 33.3,
  '3 soruluk kazanımda 1 doğru 2 yanlış → %33,3', yas);
check(Number(yas.lost_net) === 3.75, 'net kaybı: 2 yanlış × 1,25 × 1,5', yas);
check(!v2.some((x) => x.outcome === 'Sayılar' && x.questions > 1), 'iptal soru kazanım analizine girmez', v2);
check((await rows(`select 1 from public.v_student_outcome_analysis where student_id = $1`, [A.student])).length === 0, 'öğrenci başkasının analizini görmez');
await asUser(A.parent);
check((await rows(`select 1 from public.v_student_outcome_analysis where student_id = $1`, [A.student])).length > 0, 'veli çocuğunun analizini görür');
await asUser(A.admin);
const cl = await rows(`select * from public.v_class_outcome_analysis where key_id = $1 and outcome = 'Problemler — Yaş problemleri'`, [key]);
check(cl.length === 1 && cl[0].students === 2 && Number(cl[0].success_pct) === 50, 'sınıf: 6 sorudan 3 doğru → %50', cl);
const qd = await rows(`select * from public.v_question_difficulty where key_id = $1 and subject_id = $2 order by question_no`, [key, mat]);
check(qd.length === 4 && Number(qd[0].correct_pct) === 100 && Number(qd[1].correct_pct) === 0, 'soru zorluğu (iptal hariç)', qd);
await asUser(B.admin);
check((await rows(`select 1 from public.v_institution_outcome_analysis where key_id = $1`, [key])).length === 0, 'başka kurum analizi görmez');

console.log('Raporlar');
await asUser(A.admin);
const rep = (await one(`select public.exam_report($1) r`, [key])).r;
check(rep.students === 2 && rep.classes.length === 1 && rep.weak_outcomes.length > 0 && rep.ranking.length === 2,
  'müdür raporu', { s: rep.students, c: rep.classes.length, r: rep.ranking.length });
check(rep.weak_outcomes[0].success_pct <= rep.weak_outcomes[rep.weak_outcomes.length - 1].success_pct, 'zayıf kazanımlar artan sırada');
await asUser(A.student);
await expectError('öğrenci kurum raporunu alamaz', () => db.query(`select public.exam_report($1)`, [key]), 'KEY_NOT_FOUND');
const ctx = (await one(`select public.exam_card_context($1) c`, [r1.e.id])).c;
check(ctx.org_count === 2 && ctx.class_count === 2 && ctx.class_name === '12-A', 'karne: kurum ve sınıf kişi sayısı', ctx);
await asUser(B.student);
await expectError('başkasının karne bilgisi alınamaz', () => db.query(`select public.exam_card_context($1)`, [r1.e.id]), 'NOT_ALLOWED');

await asUser(A.coach);
check((await rows(`select * from public.exam_import_roster()`)).length === 2, 'koç kurumun öğrenci listesini alır');
await asUser(A.student);
check((await rows(`select * from public.exam_import_roster()`)).length === 0, 'öğrenci listeyi alamaz');

console.log('Elle girilen deneme');
await asUser(A.coach);
const man = (await one(`insert into public.exams (student_id, exam_type, name, total_net, rank_org) values ($1, 'TYT', 'Kendi denemem', 99, 1) returning *`, [A.student]));
check(man.total_net === null && man.rank_org === null, 'elle girilen denemede sıralama / toplam net yazılamaz', man);
await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct, wrong, blank, wrong_penalty) values ($1, $2, 10, 4, 0, 0)`, [man.id, mat]);
const mr = await one(`select net, wrong_penalty from public.exam_subject_results where exam_id = $1`, [man.id]);
check(Number(mr.net) === 9 && Number(mr.wrong_penalty) === 0.25, 'elle girilen denemede katsayı 0,25 (değiştirilemez)', mr);

console.log('Kamerayla okuma');
await asUser(A.coach);
const key2 = (await one(`select public.save_exam(null, $1) id`, [def({ name: 'Taslak 2' })])).id;
const sub = (await one(`select public.submit_optic($1, $2, $3, 'A') r`, [key2, A.student, JSON.stringify(sheet1)])).r;
check(sub.exam_id === null && sub.correct === 4 && Number(sub.net) === 4.88, 'taslakta kamera okuması önizleme döner, deneme yazmaz', sub);
const sub2 = (await one(`select public.submit_optic($1, $2, $3, 'A') r`, [key, A.student2, JSON.stringify(sheet1)])).r;
check(sub2.exam_id !== null && sub2.updated === true, 'yayındaki sınavda güncellenir', sub2);

console.log('Geri alma ve yeniden uygulama');
await asSuper();
const name = '20261105170000_exam_import';
const later = migs.filter((f) => f > `${name}.sql`).map((f) => f.replace('.sql', '')).reverse();
for (const l of later) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.exam_sheets') t`)).t === null, 'tablolar kaldırıldı');
check(Number((await one(`select net from public.exam_subject_results where exam_id = $1`, [man.id])).net) === 9, 'net yeniden doğru − yanlış / 4');
await db.exec(read(migDir, `${name}.sql`));
for (const l of [...later].reverse()) await db.exec(read(migDir, `${l}.sql`));
check((await one(`select count(*)::int c from public.exam_sheets`)).c >= 2, 'yeniden uygulandı, ham optikler denemelerden geri geldi');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
