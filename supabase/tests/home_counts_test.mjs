// Kısayol sayıları, eski bildirim temizliği, toplu deneme yükleme
// (20261019130000_home_counts_cleanup_import) ve geri alma.
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
async function coachIn(admin, name) {
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, name);
  await asUser(coach);
  return { id: coach, code: (await one(`select public.create_invite('student', null, 10) c`)).c };
}
async function parentOf(student, name) {
  await asUser(student);
  return signUp((await one(`select public.create_invite('parent') c`)).c, name);
}
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  return { org, admin: await signUp(code, `${name} Müdür`) };
}


const A = await school('Bal Akademi', 'ADMINHC1');
const ayse = await coachIn(A.admin, 'Ayşe Koç');
const elif = await signUp(ayse.code, 'Elif Yılmaz');
const can = await signUp(ayse.code, 'Can Kaya');
const B = await school('Yıldız', 'ADMINHC2');
const bCoach = await coachIn(B.admin, 'Yıldız Koç');
const bStudent = await signUp(bCoach.code, 'Yıldız Öğrenci');

await asSuper();
const subj = async (code) => (await one(`select id from public.subjects where code = $1`, [code])).id;
const mat = await subj('TYT_MAT');

// --- Kısayol sayıları ------------------------------------------------------------
console.log('Kısayol sayıları');
await db.query(`insert into public.study_sessions (student_id, type, started_at, duration_sec) values
  ($1, 'pomodoro', now() - interval '1 day', 1500),   -- çiçek
  ($1, 'pomodoro', now() - interval '2 days', 600),   -- soldu (pomodoro < 20 dk)
  ($1, 'free', now() - interval '3 days', 300),       -- filiz (serbest, kısa ama solmaz)
  ($1, 'pomodoro', now() - interval '400 days', 3000)`, [elif]);
await asUser(elif);
await db.query(`insert into public.mistake_cards (student_id, subject_id, due_on, mastered_at) values
  ($1, $2, current_date - 1, null), ($1, $2, current_date, null),
  ($1, $2, current_date + 2, null), ($1, $2, current_date - 5, now())`, [elif, mat]);
const counts = async (who, student, today = null) => {
  await asUser(who);
  return (await one(`select public.student_shortcut_counts($1, coalesce($2::date, current_date)) c`, [student, today])).c;
};
let c = await counts(elif, elif);
check(c.flowers === 3, 'solmuş pomodoro hariç tüm oturumlar çiçek (eskiler dahil)', c);
check(c.mistakes_due === 2 && c.mistakes_total === 4, 'tekrarı gelen 2 kart, toplam 4', c);
c = await counts(elif, elif, '2099-01-01');
check(c.mistakes_due === 3, 'öğrencinin günü ilerideyse daha çok kart', c);
c = await counts(ayse.id, elif);
check(c.flowers === 3 && c.mistakes_due === 2, 'koç da görür', c);
c = await counts(can, elif);
check(c.flowers === 0 && c.mistakes_total === 0, 'başka öğrenci 0 görür (RLS)', c);
c = await counts(bCoach.id, elif);
check(c.flowers === 0, 'başka kurumun koçu 0 görür');

await asUser(elif);
const h = (await one(`select public.student_home($1, current_date - 29, now() - interval '29 days') h`, [elif])).h;
check(h.shortcuts?.flowers === 3 && h.shortcuts?.mistakes_due === 2, 'student_home paketinde de var', h.shortcuts);
const h4 = (await one(`select public.student_home($1, current_date - 29, now() - interval '29 days', '2099-01-01') h`, [elif])).h;
check(h4.shortcuts?.mistakes_due === 3, 'student_home p_today alır', h4.shortcuts);

// --- Eski bildirimleri temizleme --------------------------------------------------
console.log('Eski bildirim temizliği');
await asSuper();
await db.exec(`delete from public.notifications`);
await db.query(`insert into public.notifications (user_id, kind, data, created_at) values
  ($1, 'daily_question', '{}', now() - interval '120 days'),
  ($1, 'daily_question', '{}', now() - interval '91 days'),
  ($1, 'daily_question', '{}', now() - interval '10 days'),
  ($1, 'announcement', '{}', now() - interval '200 days')`, [elif]);
check((await one(`select public.cleanup_old_notifications() n`)).n === 2, '90 günden eski 2 bildirim silindi');
const left = (await db.query(`select kind from public.notifications order by kind`)).rows.map((r) => r.kind);
check(JSON.stringify(left) === JSON.stringify(['announcement', 'daily_question']), 'yeni bildirim ve eski duyuru kalır', left);
check((await one(`select public.cleanup_old_notifications(1) n`)).n === 0, '1 gün istense de en az 30 gün tutulur');
await asUser(elif);
await expectError('öğrenci temizliği çağıramaz', () => db.query(`select public.cleanup_old_notifications()`), 'permission');

// --- Toplu deneme yükleme ---------------------------------------------------------
console.log('Toplu deneme yükleme');
const exam = { exam_type: 'TYT', field: null, name: 'Özdebir TYT-3', publisher: 'Özdebir', taken_on: '2026-10-18' };
const res = (code = 'TYT_MAT') => [{ code, correct: 30, wrong: 5, blank: 5 }, { code: 'TYT_TUR', correct: 32, wrong: 4, blank: 4 }];
const batch = (await one(`select gen_random_uuid() id`)).id;
await asUser(ayse.id);
let r = (await one(`select public.import_exam_batch($1, $2, $3) r`, [batch, exam, JSON.stringify([
  { student_id: elif, results: res() },
  { student_id: can, results: res() },
  { student_id: bStudent, results: res() },       // başka kurum: yetki yok
  { student_id: can, results: res('YOK_KOD') },   // bilinmeyen ders
  { student_id: elif, results: [] },              // boş sonuç
])])).r;
check(r.saved === 2, '2 öğrenciye kaydedildi', r);
check(r.failed.length === 3 && r.failed.includes(bStudent), 'hatalılar ayrı döner, diğerleri etkilenmez', r);
await asSuper();
const ex = (await db.query(`select e.student_id, e.source, e.batch_id, e.created_by, count(r.*)::int n
  from public.exams e left join public.exam_subject_results r on r.exam_id = e.id
  where e.name = 'Özdebir TYT-3' group by 1, 2, 3, 4`)).rows;
check(ex.length === 2 && ex.every((x) => x.n === 2 && x.source === 'import' && x.batch_id === batch && x.created_by === ayse.id),
  'denemeler paket, kaynak ve sonuçlarıyla', ex);
check((await one(`select count(*)::int c from public.exams where student_id = $1 and name = 'Özdebir TYT-3'`, [bStudent])).c === 0,
  'başka kurumun öğrencisine yazılmadı');
check((await one(`select count(*)::int c from public.notifications where kind = 'exam'`)).c === 2,
  'öğrencilere deneme bildirimi gitti');
await asUser(ayse.id);
check((await one(`select public.delete_exam_batch($1) n`, [batch])).n === 2, 'paket yine tek seferde silinir');
await asUser(elif);
r = (await one(`select public.import_exam_batch(gen_random_uuid(), $1, $2) r`, [exam, JSON.stringify([{ student_id: can, results: res() }])])).r;
check(r.saved === 0 && r.failed.length === 1, 'öğrenci başkasına deneme ekleyemez', r);
await asUser(ayse.id);
const many = Array.from({ length: 501 }, () => ({ student_id: elif, results: res() }));
await expectError('501 satır reddedilir', () => db.query(`select public.import_exam_batch(gen_random_uuid(), $1, $2)`, [exam, JSON.stringify(many)]), 'IMPORT_TOO_LARGE');

// --- Geri alma ---------------------------------------------------------------------
console.log('Geri alma ve yeniden uygulama');
const name = '20261019130000_home_counts_cleanup_import';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regprocedure('public.import_exam_batch(uuid, jsonb, jsonb)') f`)).f === null, 'import_exam_batch kaldırıldı');
check((await one(`select to_regprocedure('public.student_home(uuid, date, timestamptz)') f`)).f !== null, 'eski student_home geri geldi');
await asUser(elif);
const old = (await one(`select public.student_home($1, current_date - 29, now() - interval '29 days') h`, [elif])).h;
check(old.shortcuts === undefined && Array.isArray(old.logs), 'eski student_home çalışır');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
await asUser(elif);
check((await one(`select public.student_home($1, current_date - 29, now() - interval '29 days') h`, [elif])).h.shortcuts.flowers === 3,
  'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
