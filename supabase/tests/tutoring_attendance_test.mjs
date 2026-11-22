// Soru çözümü devam işareti ve geçmiş (20261122120000_tutoring_attendance).
// Soru çözümü / birebir / etüt oturumları (20261111120000_tutoring_sessions):
// müdür oturum açar, öğrenci talep eder, yalnızca öğretmen karar verir, koç
// kendi öğrencilerininkini görür; kurallar, bildirimler, geri alma.
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
const rows = async (sql, p = []) => (await db.query(sql, p)).rows;
async function expectError(n, fn, pattern) {
  try { await fn(); bad(n, 'hata bekleniyordu'); }
  catch (e) { (!pattern || e.message.includes(pattern)) ? ok(n) : bad(n, e.message); }
}
async function signUp(code, name, extra = {}) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true,
      privacy_version: '1.0', ...extra })])).id;
}
const invite = async (as, role) => { await asUser(as); return (await one(`select public.create_invite($1) c`, [role])).c; };
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  const admin = await signUp(code, `${name} Müdür`);
  const coach = await signUp(await invite(admin, 'coach'), `${name} Koç`);
  const coach2 = await signUp(await invite(admin, 'coach'), `${name} İkinci Koç`);
  const s1 = await signUp(await invite(coach, 'student'), `${name} Ali`);
  const s2 = await signUp(await invite(coach, 'student'), `${name} Ayşe`);
  const s3 = await signUp(await invite(coach2, 'student'), `${name} Can`);
  const teacherUser = await signUp(await invite(admin, 'teacher'), `${name} Selin`, { teacher_branches: ['Matematik'] });
  await asSuper();
  const teacher = (await one(`select id from public.teachers where profile_id = $1`, [teacherUser])).id;
  return { org, admin, coach, coach2, s1, s2, s3, teacherUser, teacher };
}

const A = await school('Bal Akademi', 'ADMINSS1');
const B = await school('Arı Kurs', 'ADMINSS2');

// Türkiye saatiyle yarından sonraki ilk pazartesi değil: 2 gün sonrası (hep gelecekte).
await asSuper();
const target = (await one(`select (public.tr_now()::date + 2) d, extract(isodow from public.tr_now()::date + 2)::int dow`));
const D = target.d instanceof Date ? target.d.toISOString().slice(0, 10) : String(target.d);
const DOW = target.dow;

console.log('Müdür oturum açar');
await asUser(A.admin);
const sess = await one(`insert into public.tutoring_sessions (teacher_id, kind, day, start_time, end_time, capacity, org_id)
  values ($1, 'question_solving', $2, '15:00', '16:00', 2, $3) returning *`, [A.teacher, DOW, B.org]);
check(sess.org_id === A.org, 'kurum sunucuda yazıldı', sess);
const priv = await one(`insert into public.tutoring_sessions (teacher_id, kind, day, start_time, end_time, capacity, branch)
  values ($1, 'private_lesson', $2, '17:00', '17:40', 5, ' Geometri ') returning *`, [A.teacher, DOW]);
check(priv.capacity === 1 && priv.branch === 'Geometri', 'birebirde kontenjan 1, branş kırpıldı', priv);
await expectError('aynı öğretmene çakışan oturum reddedilir',
  () => db.query(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time) values ($1, $2, '15:30', '16:30')`, [A.teacher, DOW]),
  'TUTOR_SESSION_OVERLAP');
await expectError('başka kurumun öğretmeni reddedilir',
  () => db.query(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time) values ($1, 1, '10:00', '11:00')`, [B.teacher]),
  'TUTOR_BAD_REF');
// Yayındaki programda dersi olan saate oturum açılamaz.
const slot = (await one(`insert into public.time_slots (day, seq, start_time, end_time) values ($1, 1, '09:00', '09:40') returning id`, [DOW])).id;
const klass = (await one(`insert into public.classrooms (name) values ('12-A') returning id`)).id;
const sch = (await one(`insert into public.schedules (name) values ('Güz') returning id`)).id;
await db.query(`insert into public.schedule_entries (schedule_id, teacher_id, classroom_id, time_slot_id, branch)
  values ($1, $2, $3, $4, 'Matematik')`, [sch, A.teacher, klass, slot]);
await db.query(`select public.publish_schedule($1)`, [sch]);
await expectError('programda dersi olan saatte oturum açılamaz',
  () => db.query(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time) values ($1, $2, '09:20', '10:00')`, [A.teacher, DOW]),
  'TUTOR_TEACHER_BUSY');

for (const [who, id] of [['koç', A.coach], ['öğretmen', A.teacherUser], ['öğrenci', A.s1]]) {
  await asUser(id);
  await expectError(`${who} oturum açamaz`,
    () => db.query(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time) values ($1, 2, '20:00', '21:00')`, [A.teacher]));
  check((await rows(`select id from public.tutoring_sessions`)).length === 0, `${who} tabloyu doğrudan okuyamaz`);
  check((await rows(`select id from public.tutoring_requests`).catch(() => [])).length === 0, `${who} talepleri doğrudan okuyamaz`);
}
await asUser(B.admin);
check((await rows(`select id from public.tutoring_sessions`)).length === 0, 'öteki kurumun müdürü görmez');

console.log('Geçmiş talepler ve geldi / gelmedi');
// Geçmişe talep elle eklenir (uygulama geçmişe talep açtırmaz).
await asSuper();
const past = async (student, daysAgo, status = 'approved') => (await one(
  `insert into public.tutoring_requests (org_id, tenant_id, session_id, student_id, on_date, status)
   select s.org_id, o.tenant_id, s.id, $1, public.tr_now()::date - $2::int, $3
   from public.tutoring_sessions s join public.organizations o on o.id = s.org_id
   where s.id = $4 returning id`, [student, daysAgo, status, sess.id])).id;
const p1 = await past(A.s1, 3);
const p2 = await past(A.s2, 5, 'rejected');
const fut = (await one(`insert into public.tutoring_requests (org_id, tenant_id, session_id, student_id, on_date, status)
  select s.org_id, o.tenant_id, s.id, $1, public.tr_now()::date + 4, 'approved'
  from public.tutoring_sessions s join public.organizations o on o.id = s.org_id where s.id = $2 returning id`, [A.s1, sess.id])).id;

await asUser(A.teacherUser);
await db.query(`select public.mark_tutoring_attendance($1, true)`, [p1]);
const h = await rows(`select * from public.teacher_tutoring_history(30)`);
check(h.length === 1 && h[0].id === p1 && h[0].attended === true, 'öğretmen geldi işaretler, geçmişte onaylı olan görünür', h);
await db.query(`select public.mark_tutoring_attendance($1, false)`, [p1]);
check((await rows(`select attended from public.teacher_tutoring_history(30)`))[0].attended === false, 'gelmedi olarak değiştirilir');
await db.query(`select public.mark_tutoring_attendance($1, null)`, [p1]);
check((await rows(`select attended from public.teacher_tutoring_history(30)`))[0].attended === null, 'işaret geri alınır');
await expectError('henüz yapılmamış oturum işaretlenemez', () => db.query(`select public.mark_tutoring_attendance($1, true)`, [fut]), 'TUTOR_NOT_YET');
await expectError('reddedilen talep işaretlenemez', () => db.query(`select public.mark_tutoring_attendance($1, true)`, [p2]), 'TUTOR_NOT_APPROVED');
check((await rows(`select * from public.teacher_tutoring_history(2)`)).length === 0, 'gün aralığı dışındaki gelmez');

for (const [who, id] of [['koç', A.coach], ['öğrenci', A.s1], ['öteki kurumun öğretmeni', B.teacherUser]]) {
  await asUser(id);
  await expectError(`${who} devam işaretleyemez`, () => db.query(`select public.mark_tutoring_attendance($1, true)`, [p1]), 'NOT_ALLOWED');
}
await asUser(A.coach);
check((await rows(`select * from public.teacher_tutoring_history(30)`)).length === 0, 'koç öğretmen geçmişini görmez');

await asUser(A.teacherUser);
await db.query(`select public.mark_tutoring_attendance($1, true)`, [p1]);
await asUser(A.s1);
const mine = await rows(`select * from public.my_tutoring_history(60)`);
check(mine.length === 1 && mine[0].id === p1 && mine[0].attended === true && mine[0].status === 'approved', 'öğrenci geçmişini ve devam durumunu görür', mine);
await asUser(A.s2);
const mine2 = await rows(`select * from public.my_tutoring_history(60)`);
check(mine2.length === 1 && mine2[0].status === 'rejected', 'öğrenci reddedileni de görür');
await asUser(A.s3);
check((await rows(`select * from public.my_tutoring_history(60)`)).length === 0, 'başkasının geçmişi görünmez');
await asSuper();
await db.exec(`set role anon`);
await expectError('anonim çağıramaz', () => db.query(`select * from public.my_tutoring_history(60)`), 'permission');

console.log('Geri alma ve yeniden uygulama');
await asSuper();
await db.exec(read(rbDir, '20261122120000_tutoring_attendance.down.sql'));
check((await one(`select count(*)::int c from information_schema.columns where table_name = 'tutoring_requests' and column_name = 'attended'`)).c === 0, 'rollback sütunu kaldırır');
await db.exec(read(migDir, '20261122120000_tutoring_attendance.sql'));
ok('yeniden uygulandı');

console.log(failures ? `\n${failures} test başarısız` : '\nHepsi geçti');
process.exit(failures ? 1 : 0);
