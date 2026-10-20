import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';

const root = process.argv[2] ?? "../..";
const migDir = `${root}/supabase/migrations`;
const migrations = fs.readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort()
  .map((f) => fs.readFileSync(`${migDir}/${f}`, 'utf8'));
const seed = fs.readFileSync(`${root}/supabase/seed.sql`, 'utf8') + String.fromCharCode(10) + fs.readFileSync(`${root}/supabase/seed_ayt_ydt_topics.sql`, 'utf8');

const db = new PGlite();
let failures = 0;
const ok = (name) => console.log('  PASS', name);
const bad = (name, info) => { failures++; console.log('  FAIL', name, info ?? ''); };

// Supabase ortamı taklidi
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

for (const m of migrations) await db.exec(m);
ok(`${migrations.length} migrations applied`);
await db.exec(seed); ok('seed applied');
const { rows: [{ c }] } = await db.query(`select count(*)::int c from public.topics`);
console.log('  topics:', c);

const asSuper = () => db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
const asUser = (id) => db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
const asAnon = () => db.exec(`set role anon; select set_config('request.jwt.claim.sub', '', false);`);

async function signUp(code, name = 'Test Kullanıcı') {
  await asSuper();
  const { rows } = await db.query(
    `insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true })]);
  return rows[0].id;
}
async function expectError(name, fn, pattern) {
  try { await fn(); bad(name, '(hata bekleniyordu)'); }
  catch (e) { (!pattern || e.message.includes(pattern)) ? ok(name) : bad(name, e.message); }
}
async function rpc(sql, params = []) { return (await db.query(sql, params)).rows[0]; }

// --- Kurum ve müdür (süper-admin elle oluşturur)
await asSuper();
const org = (await rpc(`insert into public.organizations (name, seat_limit) values ('Bal Akademi', 2) returning id`)).id;
const org2 = (await rpc(`insert into public.organizations (name, seat_limit) values ('Başka Kurum', 5) returning id`)).id;
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMIN001', $1, 'admin'), ('ADMIN002', $2, 'admin')`, [org, org2]);

await asAnon();
const info = await rpc(`select public.check_invite(' admin001 ') r`);
info.r?.role === 'admin' && info.r?.org_name === 'Bal Akademi' ? ok('check_invite (anon)') : bad('check_invite', info);
const none = await rpc(`select public.check_invite('YOKKOD99') r`);
none.r === null ? ok('check_invite invalid -> null') : bad('check_invite invalid', none);

await expectError('signup without code fails', () => signUp(''), 'INVITE_REQUIRED');
await expectError('signup with bad code fails', () => signUp('NOPE1234'), 'INVITE_INVALID');

const admin = await signUp('ADMIN001', 'Ayşe Müdür');
const admin2 = await signUp('ADMIN002', 'Diğer Müdür');
await expectError('used code cannot be reused', () => signUp('ADMIN001'), 'INVITE_INVALID');

// --- Müdür koç daveti üretir
await asUser(admin);
const coachCode = (await rpc(`select public.create_invite('coach') c`)).c;
coachCode?.length === 8 ? ok('admin creates coach invite') : bad('coach invite', coachCode);
await expectError('admin cannot invite parent', () => db.query(`select public.create_invite('parent')`), 'NOT_ALLOWED');
const coach = await signUp(coachCode, 'Kerem Koç');

// --- Koç öğrenci daveti üretir (3 kullanımlık, kota 2)
await asUser(coach);
const stuCode = (await rpc(`select public.create_invite('student', null, 3) c`)).c;
const student = await signUp(stuCode, 'Elif Öğrenci');
const student2 = await signUp(stuCode, 'Can Öğrenci');
await expectError('kredi bitince kayıt reddedilir', () => signUp(stuCode), 'NO_CREDITS');

// --- Öğrenci veli daveti üretir
await asUser(student);
const parentCode = (await rpc(`select public.create_invite('parent') c`)).c;
{
  await asSuper();
  const days = await rpc(`select extract(day from expires_at - created_at)::int d from public.invite_codes where code = $1`, [parentCode]);
  days.d === 30 ? ok('veli davet kodu 30 gün geçerli') : bad('parent invite days', days);
  await asUser(student);
}
const parent = await signUp(parentCode, 'Veli Hanım');
await asSuper();
const link = await rpc(`select count(*)::int c from public.parent_students where parent_id = $1 and student_id = $2`, [parent, student]);
link.c === 1 ? ok('parent linked to student') : bad('parent link');
const cs = await rpc(`select count(*)::int c from public.coach_students where coach_id = $1`, [coach]);
cs.c === 2 ? ok('students linked to coach') : bad('coach links', cs);

// --- Öğrenci deneme yazamaz; koç kendi öğrencisine yazar
await asUser(student);
await expectError('student cannot insert own exam',
  () => db.query(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'x')`, [student]));

await asUser(coach);
const exam = (await rpc(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'Deneme 1') returning id, created_by`, [student]));
exam.created_by === coach ? ok('coach inserts exam for student (created_by set)') : bad('created_by', exam);
await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct, wrong, blank)
  select $1, id, 30, 8, 2 from public.subjects where code = 'TYT_MAT'`, [exam.id]);
const net = await rpc(`select net::float n from public.exam_subject_results where exam_id = $1`, [exam.id]);
net.n === 28 ? ok('net = 30 - 8/4 = 28') : bad('net', net);

// Başka kurumun koçu bu öğrenciye yazamaz
await asUser(admin2);
const coach2Code = (await rpc(`select public.create_invite('coach') c`)).c;
const coach2 = await signUp(coach2Code, 'Başka Koç');
await asUser(coach2);
await expectError('other coach cannot insert exam for student',
  () => db.query(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'x')`, [student]));

// Okul numarası
await asUser(coach);
await db.query(`select public.set_student_number($1, ' 1042 ')`, [student]);
const num = await rpc(`select student_number n from public.profiles where id = $1`, [student]);
num.n === '1042' ? ok('coach sets student number (trimmed)') : bad('student number', num);
await expectError('number unique within org',
  () => db.query(`select public.set_student_number($1, '1042')`, [student2]), 'NUMBER_TAKEN');
await asUser(student);
await expectError('student cannot set own number',
  () => db.query(`select public.set_student_number($1, '9')`, [student]), 'NOT_ALLOWED');
await expectError('student cannot update number column',
  () => db.query(`update public.profiles set student_number = '9' where id = $1`, [student]), 'permission denied');

// Koç / müdür özeti
await asUser(student);
await db.query(`insert into public.question_logs (student_id, subject_id, correct, wrong, blank)
  select $1, id, 30, 5, 5 from public.subjects where code = 'TYT_MAT'`, [student]);
await db.query(`insert into public.study_sessions (student_id, started_at, duration_sec) values ($1, now(), 1500)`, [student]);
await asUser(coach);
await db.query(`insert into public.tasks (coach_id, student_id, title) values ($1, $2, 'Paragraf 40 soru')`, [coach, student]);
const sums = (await db.query(`select * from public.student_summaries()`)).rows;
const mine = sums.find((r) => r.student_id === student);
sums.length === 2 && mine?.exam_count === 1 && Number(mine.last_total_net) === 28 && mine.student_number === '1042'
  && mine.week_questions === 40 && mine.week_minutes === 25 && mine.pending_tasks === 1 && mine.coach_name === 'Kerem Koç'
  ? ok('coach summaries (weekly stats, tasks, coach name)') : bad('coach summaries', sums);
await asUser(admin);
(await db.query(`select * from public.student_summaries()`)).rows.length === 2
  ? ok('admin sees all org students in summary') : bad('admin summaries');
await asUser(coach2);
(await db.query(`select * from public.student_summaries()`)).rows.length === 0
  ? ok('other coach summary empty') : bad('coach2 summaries');
await asUser(student);
(await db.query(`select * from public.student_summaries()`)).rows.length === 0
  ? ok('student summary empty') : bad('student summaries');
await asSuper();
const ayt = await rpc(`select count(*)::int c from public.topics t join public.subjects s on s.id = t.subject_id where s.exam_type <> 'TYT'`);
ayt.c > 100 ? ok(`AYT/YDT topics seeded (${ayt.c})`) : bad('ayt topics', ayt);

// --- Görünürlük
const seen = async (uid) => { await asUser(uid); return (await rpc(`select count(*)::int c from public.exams`)).c; };
(await seen(parent)) === 1 ? ok('parent sees child exam') : bad('parent visibility');
(await seen(coach)) === 1 ? ok('coach sees student exam') : bad('coach visibility');
(await seen(admin)) === 1 ? ok('admin sees org exam') : bad('admin visibility');
(await seen(student2)) === 0 ? ok('other student sees nothing') : bad('student2 visibility');
(await seen(admin2)) === 0 ? ok('other org admin sees nothing') : bad('admin2 visibility');

await asUser(parent);
await expectError('parent cannot insert exam',
  () => db.query(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'x')`, [student]));
const parentNotes = await rpc(`select count(*)::int c from public.coach_notes`);

// --- Görevler
await asUser(coach);
const task = (await rpc(`insert into public.tasks (coach_id, student_id, title) values ($1, $2, '100 problem sorusu') returning id`, [coach, student])).id;
await db.query(`insert into public.coach_notes (coach_id, student_id, body) values ($1, $2, 'Harika gidiyorsun')`, [coach, student]);
await asUser(student);
await db.query(`update public.tasks set status = 'done' where id = $1`, [task]);
const t = await rpc(`select status, completed_at is not null done from public.tasks where id = $1`, [task]);
t.status === 'done' && t.done ? ok('student completes task') : bad('task complete', t);
await expectError('student cannot edit task title',
  () => db.query(`update public.tasks set title = 'hiç' where id = $1`, [task]), 'STUDENT_CAN_ONLY_UPDATE_STATUS');
const notes = await rpc(`select count(*)::int c from public.coach_notes`);
notes.c === 1 ? ok('student sees coach note') : bad('student notes', notes);
await asUser(parent);
(await rpc(`select count(*)::int c from public.coach_notes`)).c === 0 ? ok('parent cannot see coach notes') : bad('parent notes');

// --- Lisans alanı korunuyor
await asUser(admin);
await expectError('admin cannot change seat_limit',
  () => db.query(`update public.organizations set seat_limit = 999 where id = $1`, [org]), 'permission denied');
await db.query(`update public.organizations set name = 'Bal Akademi 2' where id = $1`, [org]);
ok('admin can rename org');
await asUser(student);
await expectError('student cannot change own role',
  () => db.query(`update public.profiles set role = 'admin' where id = $1`, [student]), 'permission denied');
await expectError('student cannot write subjects',
  () => db.query(`insert into public.subjects (code, exam_type, name, question_count) values ('X', 'TYT', 'x', 1)`));

// --- Hesap silme
await asUser(admin);
await expectError('last admin cannot delete account', () => db.query(`select public.delete_my_account()`), 'LAST_ADMIN');
await asUser(coach);
await expectError('coach with students cannot delete', () => db.query(`select public.delete_my_account()`), 'COACH_HAS_STUDENTS');

// --- Ödev paketleri ve bildirimler
console.log('assignments & notifications');
await asSuper();
const matTopic = (await rpc(`select t.id from public.topics t join public.subjects s on s.id = t.subject_id where s.code = 'TYT_MAT' order by t.sort limit 1`)).id;
const items = JSON.stringify([
  { subject_code: 'TYT_MAT', topic_id: matTopic, question_count: 30, note: 'Önce konu tekrarı' },
  { subject_code: 'TYT_TUR', question_count: 40 },
]);
await asUser(coach);
const asg = (await rpc(`select public.send_assignment($1, 'Hafta 1 ödevi', $2::jsonb, current_date + 7) id`, [student, items])).id;
asg ? ok('coach sends assignment') : bad('send_assignment');
await expectError('empty assignment rejected', () => db.query(`select public.send_assignment($1, 'Boş', '[]'::jsonb)`, [student]), 'EMPTY_ASSIGNMENT');
await expectError('unknown subject rejected', () => db.query(`select public.send_assignment($1, 'X', '[{"subject_code":"YOK"}]'::jsonb)`, [student]), 'INVALID_SUBJECT');
await expectError('coach cannot insert assignment directly', () => db.query(`insert into public.assignments (student_id, title) values ($1, 'x')`, [student]));

await asUser(coach2);
await expectError('other coach cannot send', () => db.query(`select public.send_assignment($1, 'X', $2::jsonb)`, [student, items]), 'NOT_ALLOWED');
const c2see = await rpc(`select count(*)::int c from public.assignments`);
c2see.c === 0 ? ok('other coach sees no assignments') : bad('coach2 sees assignments', c2see);

await asUser(student);
const mineA = await rpc(`select count(*)::int c from public.assignment_items i join public.assignments a on a.id = i.assignment_id where a.id = $1`, [asg]);
mineA.c === 2 ? ok('student sees 2 items') : bad('student items', mineA);
const item = (await rpc(`select id from public.assignment_items where assignment_id = $1 order by sort limit 1`, [asg])).id;
await db.query(`update public.assignment_items set done = true where id = $1`, [item]);
const ticked = await rpc(`select done, done_at is not null stamped from public.assignment_items where id = $1`, [item]);
ticked.done && ticked.stamped ? ok('student ticks item (done_at stamped)') : bad('tick', ticked);
await expectError('student cannot change question count', () => db.query(`update public.assignment_items set question_count = 1 where id = $1`, [item]));
await expectError('student cannot delete assignment', async () => {
  const r = await db.query(`delete from public.assignments where id = $1 returning id`, [asg]);
  if (r.rows.length === 0) throw new Error('blocked');
});

const notes1 = (await db.query(`select kind, data from public.notifications order by created_at`)).rows;
notes1.some((n) => n.kind === 'assignment' && n.data.items === 2 && n.data.from === 'Kerem Koç')
  ? ok('student notified of assignment') : bad('assignment notification', notes1);
notes1.some((n) => n.kind === 'task') ? ok('student notified of task') : bad('task notification', notes1);
notes1.some((n) => n.kind === 'exam') ? ok('student notified of exam') : bad('exam notification', notes1);
await expectError('student cannot forge notification', () => db.query(`insert into public.notifications (user_id, kind) values ($1, 'exam')`, [student]));
await db.query(`update public.notifications set read_at = now() where read_at is null`);
const unread = await rpc(`select count(*)::int c from public.notifications where read_at is null`);
unread.c === 0 ? ok('student marks notifications read') : bad('mark read', unread);
await expectError('notify() not callable', () => db.query(`select public.notify($1, 'exam', '{}'::jsonb, null)`, [student]));

await asUser(parent);
const pSee = await rpc(`select (select count(*)::int from public.assignments) a, (select count(*)::int from public.notifications) n`);
pSee.a === 1 && pSee.n === 0 ? ok('parent sees assignment but not student notifications') : bad('parent view', pSee);

await asUser(coach);
await db.query(`delete from public.assignments where id = $1`, [asg]);
const left = await rpc(`select count(*)::int c from public.assignment_items where assignment_id = $1`, [asg]);
left.c === 0 ? ok('coach deletes assignment (items cascade)') : bad('delete assignment', left);

await asUser(parent);
await db.query(`select public.delete_my_account()`);
await asSuper();
const gone = await rpc(`select (select count(*)::int from auth.users where id = $1) u, (select count(*)::int from public.parent_students where parent_id = $1) l`, [parent]);
gone.u === 0 && gone.l === 0 ? ok('parent deletes own account (cascade)') : bad('parent delete', gone);
await asUser(student2);
await expectError('öğrenci kendi hesabını silemez', () => db.query(`select public.delete_my_account()`), 'STUDENT_DELETE_BY_COACH');
await asUser(coach2);
await expectError('başka koç öğrenciyi silemez', () => db.query(`select public.delete_student_account($1)`, [student2]), 'NOT_ALLOWED');
await asUser(coach);
await expectError('koç öğrenci olmayanı silemez', () => db.query(`select public.delete_student_account($1)`, [admin]), 'NOT_A_STUDENT');
const coachCodeDays = await (async () => { const c = (await rpc(`select public.create_invite('student') c`)).c; await asSuper(); const r = await rpc(`select extract(day from expires_at - created_at)::int d from public.invite_codes where code = $1`, [c]); await asUser(coach); return r.d; })();
coachCodeDays === 14 ? ok('öğrenci davet kodu 14 gün geçerli') : bad('student invite days', coachCodeDays);
await db.query(`select public.delete_student_account($1)`, [student2]);
await asSuper();
const s2 = await rpc(`select (select count(*)::int from public.profiles where id = $1) p, (select count(*)::int from auth.users where id = $1) u, (select count(*)::int from public.coach_students where student_id = $1) l`, [student2]);
s2.p === 0 && s2.u === 0 && s2.l === 0 ? ok('koç öğrencinin hesabını siler (cascade)') : bad('coach deletes student', s2);
await asAnon();
await expectError('anon cannot call delete_my_account', () => db.query(`select public.delete_my_account()`));

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
