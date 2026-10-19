// Yük azaltma (20261019120000_scale_load): toplu push kuyruğu, student_home
// RPC'si, panel özetlerinin yalnızca yönetilen öğrencilerden hesaplanması
// ve geri alma.
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


const A = await school('Bal Akademi', 'ADMINSC1');
const ayse = await coachIn(A.admin, 'Ayşe Koç');
const mehmet = await coachIn(A.admin, 'Mehmet Koç');
const elif = await signUp(ayse.code, 'Elif Yılmaz');
const can = await signUp(ayse.code, 'Can Kaya');
const zeynep = await signUp(mehmet.code, 'Zeynep Arslan');
const B = await school('Yıldız', 'ADMINSC2');
const bCoach = await coachIn(B.admin, 'Yıldız Koç');
const bStudent = await signUp(bCoach.code, 'Yıldız Öğrenci');

// --- Push kuyruğu --------------------------------------------------------------
console.log('Toplu bildirimler zamana yayılır');
await asSuper();
const queued = async () => (await one(`select count(*)::int c from public.push_queue`)).c;
// Kurulumdan kalan "son 10 saniye" bildirimlerini eskit.
await db.exec(`update public.notifications set created_at = now() - interval '1 hour'`);
await db.query(`insert into public.notifications (user_id, kind, data)
  select $1, 'daily_question', '{}'::jsonb from generate_series(1, 5)`, [elif]);
check(await queued() === 0, 'az sayıda bildirim anında gider (kuyruğa girmez)');

await db.query(`insert into public.notifications (user_id, kind, data)
  select $1, 'daily_question', '{}'::jsonb from generate_series(1, 200)`, [can]);
check(await queued() === 200, 'toplu eklemede hepsi kuyruğa girer', await queued());
const spread = await one(`select extract(epoch from max(due_at) - min(due_at))::float s,
  count(distinct due_at)::int d from public.push_queue`);
check(spread.d === 200 && spread.s > 4.5 && spread.s < 5.5,
  '200 bildirim saniyede 40 hızla ~5 saniyeye yayılır', spread);

await db.query(`insert into public.notifications (user_id, kind, data) values ($1, 'daily_question', '{}')`, [zeynep]);
check(await queued() === 201, 'yoğunluk sürerken tekli bildirim de sıraya girer');
const last = await one(`select q.due_at = (select max(due_at) from public.push_queue) latest
  from public.push_queue q join public.notifications n on n.id = q.notification_id
  where n.user_id = $1`, [zeynep]);
check(last.latest, 'yeni gelen sıranın sonuna eklenir');

await db.exec(`update public.push_queue set due_at = due_at + interval '1 hour'`);
check((await one(`select public.drain_push_queue() n`)).n === 0, 'vadesi gelmeyen gönderilmez');
await db.exec(`update public.push_queue set due_at = now() - interval '1 second'
  where notification_id in (select notification_id from public.push_queue order by due_at limit 150)`);
check((await one(`select public.drain_push_queue() n`)).n === 150, 'vadesi gelenler gönderilir');
check(await queued() === 51, 'gönderilenler kuyruktan çıkar', await queued());
await db.exec(`update public.push_queue set due_at = now() - interval '1 second'`);
check((await one(`select public.drain_push_queue(10) n`)).n === 10, 'tek seferde en fazla p_limit');
await db.exec(`delete from public.notifications where kind = 'daily_question'`);
check(await queued() === 0, 'bildirim silinince kuyruktan da düşer');

await asUser(elif);
await expectError('öğrenci kuyruğu okuyamaz', () => db.query(`select * from public.push_queue`), 'permission');
await expectError('öğrenci kuyruğu boşaltamaz', () => db.query(`select public.drain_push_queue()`), 'permission');

// --- Öğrenci ana sayfası ---------------------------------------------------------
console.log('student_home tek istekte ana sayfa verisi');
await asSuper();
const subj = async (code) => (await one(`select id from public.subjects where code = $1`, [code])).id;
const mat = await subj('TYT_MAT');
const tur = await subj('TYT_TUR');
const topic = await one(`select id, name from public.topics where subject_id = $1 order by sort limit 1`, [mat]);
await db.query(`insert into public.question_logs (student_id, subject_id, topic_id, correct, wrong, blank, logged_on)
  values ($1, $2, $3, 10, 2, 1, current_date), ($1, $4, null, 5, 0, 0, current_date - 3),
         ($1, $2, null, 7, 1, 0, current_date - 40)`, [elif, mat, topic.id, tur]);
await db.query(`insert into public.study_sessions (student_id, subject_id, type, started_at, duration_sec)
  values ($1, $2, 'pomodoro', now() - interval '1 hour', 1500), ($1, null, 'free', now() - interval '2 days', 600),
         ($1, null, 'free', now() - interval '60 days', 600)`, [elif, mat]);
await db.query(`insert into public.goals (student_id, daily_questions) values ($1, 80)`, [elif]);
await db.query(`insert into public.topic_progress (student_id, topic_id, status) values ($1, $2, 'done')`, [elif, topic.id]);
const ex1 = (await one(`insert into public.exams (student_id, exam_type, name, taken_on, created_by)
  values ($1, 'TYT', 'Deneme 1', current_date - 14, $1) returning id`, [elif])).id;
const ex2 = (await one(`insert into public.exams (student_id, exam_type, name, taken_on, created_by)
  values ($1, 'TYT', 'Deneme 2', current_date - 2, $1) returning id`, [elif])).id;
await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct, wrong, blank)
  values ($1, $3, 20, 8, 12), ($2, $3, 28, 4, 8), ($2, $4, 30, 5, 5)`, [ex1, ex2, mat, tur]);
const asg = (await one(`insert into public.assignments (coach_id, student_id, title)
  values ($1, $2, 'Türev tekrarı') returning id`, [ayse.id, elif])).id;
await db.query(`insert into public.assignment_items (assignment_id, subject_id, topic_id, question_count, sort)
  values ($1, $2, $3, 40, 1), ($1, $4, null, 20, 0)`, [asg, mat, topic.id, tur]);

const home = async (who, student) => {
  await asUser(who);
  return (await one(`select public.student_home($1, current_date - 29,
    date_trunc('day', now()) - interval '29 days') h`, [student])).h;
};
let h = await home(elif, elif);
check(h.logs.length === 2, 'son 30 günün soru kayıtları', h.logs.length);
check(h.logs[0].subjects.code === 'TYT_MAT' && h.logs[0].topics.name === topic.name && h.logs[1].topics === null,
  'kayıtlar yeniden eskiye, ders/konu iç içe', h.logs);
check(h.sessions.length === 2 && h.sessions[0].subjects.code === 'TYT_MAT' && h.sessions[1].subjects === null,
  'son 30 günün oturumları', h.sessions);
check(h.goals?.daily_questions === 80, 'hedefler', h.goals);
check(h.topic_progress.length === 1 && h.topic_progress[0].status === 'done', 'konu ilerlemesi', h.topic_progress);
check(h.exams.length === 2 && h.exams[0].name === 'Deneme 2' && h.exams[0].exam_subject_results.length === 2,
  'denemeler yeniden eskiye, sonuçlarıyla', h.exams);
check(h.assignments.length === 1 && h.assignments[0].coach?.full_name === 'Ayşe Koç'
  && h.assignments[0].assignment_items.length === 2
  && h.assignments[0].assignment_items.some((i) => i.topics?.id === topic.id),
  'ödevler, koç adı ve maddeleriyle', h.assignments);

// Aynı veriyi tek tek sorgulayınca aynı sayılar.
await asUser(elif);
const direct = await one(`select
  (select count(*)::int from public.question_logs where student_id = $1 and logged_on >= current_date - 29) logs,
  (select count(*)::int from public.exams where student_id = $1) exams,
  (select count(*)::int from public.assignments where student_id = $1) asg`, [elif]);
check(direct.logs === h.logs.length && direct.exams === h.exams.length && direct.asg === h.assignments.length,
  'ayrı sorgularla aynı sonuç', direct);

h = await home(ayse.id, elif);
check(h.logs.length === 2 && h.exams.length === 2, 'koçu öğrencisinin ana sayfasını görür');
h = await home(can, elif);
check(h.logs.length === 0 && h.exams.length === 0 && h.goals === null && h.assignments.length === 0,
  'başka öğrenci göremez (RLS)', h);
h = await home(bCoach.id, elif);
check(h.logs.length === 0 && h.exams.length === 0, 'başka kurumun koçu göremez');
h = await home(elif, can);
check(h.logs.length === 0 && h.goals === null, 'boş öğrenci: boş listeler, hedef yok', h);
await asSuper();
await db.exec(`set role anon`);
await expectError('girişsiz çağrılamaz',
  () => db.query(`select public.student_home(gen_random_uuid(), current_date, now())`), 'permission');
await asSuper();

// --- Koç / müdür panelleri ---------------------------------------------------------
console.log('Panel özetleri yalnızca yönetilen öğrencilerden hesaplanır');
const ids = (rows) => rows.map((r) => r.id).sort();
for (const [who, label] of [[ayse.id, 'koç'], [mehmet.id, 'diğer koç'], [A.admin, 'müdür'],
  [B.admin, 'diğer kurum müdürü'], [elif, 'öğrenci']]) {
  await asUser(who);
  const a = ids((await db.query(`select id from public.my_managed_students() id`)).rows);
  // Eski yöntem: tüm profilleri can_manage_student ile süz (RLS'siz, süper kullanıcı gözüyle).
  await asSuper();
  await db.exec(`select set_config('request.jwt.claim.sub', '${who}', false)`);
  const b = ids((await db.query(`select id from public.profiles where public.can_manage_student(id)`)).rows);
  check(JSON.stringify(a) === JSON.stringify(b), `${label}: küme can_manage_student ile aynı`, { a, b });
}
const summaries = async (who) => {
  await asUser(who);
  return (await db.query(`select student_id, exam_count, week_questions from public.student_summaries()`)).rows;
};
let s = await summaries(ayse.id);
check(s.length === 2 && s.find((r) => r.student_id === elif)?.exam_count === 2, 'koç kendi 2 öğrencisini görür', s);
check(s.find((r) => r.student_id === elif)?.week_questions === 18, 'haftalık soru sayısı', s);
s = await summaries(A.admin);
check(s.length === 3, 'müdür kurumundaki 3 öğrenciyi görür', s);
s = await summaries(B.admin);
check(s.length === 1 && s[0].student_id === bStudent, 'diğer kurum yalnız kendi öğrencisini görür', s);
s = await summaries(elif);
check(s.length === 0, 'öğrenci özet görmez', s);

const trends = async (who) => {
  await asUser(who);
  return (await db.query(`select student_id, exam_count, delta from public.exam_trends('TYT')`)).rows;
};
let t = await trends(ayse.id);
check(t.length === 1 && t[0].student_id === elif && t[0].exam_count === 2 && Number(t[0].delta) > 0,
  'koç öğrencisinin deneme eğilimini görür', t);
check((await trends(mehmet.id)).length === 0, 'diğer koç görmez');
check((await trends(A.admin)).length === 1, 'müdür görür');
check((await trends(B.admin)).length === 0, 'başka kurum görmez');

// --- Geri alma ---------------------------------------------------------------------
console.log('Geri alma ve yeniden uygulama');
const name = '20261019120000_scale_load';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.push_queue') t`)).t === null, 'kuyruk tablosu kaldırıldı');
check((await one(`select to_regprocedure('public.student_home(uuid, date, timestamptz)') f`)).f === null,
  'student_home kaldırıldı');
check((await summaries(ayse.id)).length === 2, 'eski student_summaries çalışır');
await asSuper();
await db.query(`insert into public.notifications (user_id, kind, data)
  select $1, 'daily_question', '{}'::jsonb from generate_series(1, 50)`, [elif]);
ok('eski tetikleyiciyle toplu bildirim eklenir');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select to_regclass('public.push_queue') t`)).t !== null, 'yeniden uygulandı');
check((await summaries(ayse.id)).length === 2, 'yeni student_summaries çalışır');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
