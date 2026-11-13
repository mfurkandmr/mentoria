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

console.log('Öğrenci açık oturumları görür ve talep eder');
await asUser(A.s1);
const open = await rows(`select * from public.open_tutoring_sessions($1, 7)`, [D]);
const mine = open.filter((o) => o.session_id === sess.id);
check(mine.length >= 1 && mine[0].teacher_name === 'Bal Akademi Selin' && mine[0].branch === 'Matematik'
  && mine[0].taken === 0 && mine[0].my_status === null, 'oturum listede, branş öğretmenden', mine);
await asUser(B.s1);
check((await rows(`select * from public.open_tutoring_sessions($1, 7)`, [D])).length === 0, 'öteki kurumun öğrencisi görmez');
await asUser(A.coach);
check((await rows(`select * from public.open_tutoring_sessions($1, 7)`, [D])).length === 0, 'koç öğrenci listesini almaz');

await asUser(A.s1);
const r1 = (await one(`select public.request_tutoring_session($1, $2, '  Türev soruları  ') id`, [sess.id, D])).id;
check(!!r1, 'talep oluştu');
await expectError('aynı oturuma ikinci talep reddedilir',
  () => db.query(`select public.request_tutoring_session($1, $2)`, [sess.id, D]), 'TUTOR_ALREADY_REQUESTED');
await expectError('günü tutmayan tarih reddedilir',
  () => db.query(`select public.request_tutoring_session($1, ($2::date + 1))`, [sess.id, D]), 'TUTOR_BAD_DATE');
await expectError('14 günden ileri tarih reddedilir',
  () => db.query(`select public.request_tutoring_session($1, ($2::date + 21))`, [sess.id, D]), 'TUTOR_BAD_DATE');
await asUser(B.s1);
await expectError('öteki kurumun öğrencisi talep edemez',
  () => db.query(`select public.request_tutoring_session($1, $2)`, [sess.id, D]), 'TUTOR_SESSION_NOT_FOUND');
await asUser(A.coach);
await expectError('koç talep edemez',
  () => db.query(`select public.request_tutoring_session($1, $2)`, [sess.id, D]), 'NOT_ALLOWED');

await asSuper();
const note = await one(`select * from public.notifications where user_id = $1 and kind = 'tutoring_request'`, [A.teacherUser]);
check(note?.data?.event === 'new' && note.data.student === 'Bal Akademi Ali' && note.data.route === '/teacher',
  'öğretmene bildirim gitti', note?.data);

console.log('Öğretmen görür ve karar verir; koç görmez');
await asUser(A.s2);
const r2 = (await one(`select public.request_tutoring_session($1, $2) id`, [sess.id, D])).id;
await asUser(A.s3);
const r3 = (await one(`select public.request_tutoring_session($1, $2) id`, [sess.id, D])).id;

await asUser(A.teacherUser);
const tq = await rows(`select * from public.teacher_tutoring_requests($1, 7)`, [D]);
check(tq.length === 3 && tq[0].topic === 'Türev soruları' && tq[0].student_name === 'Bal Akademi Ali',
  'öğretmen talepleri görür (konu kırpıldı)', tq.map((t) => [t.student_name, t.topic]));
check((await rows(`select * from public.my_tutoring_sessions()`)).length === 2, 'öğretmen kendi oturumlarını görür');

await asUser(A.coach);
await expectError('koç karar veremez',
  () => db.query(`select public.decide_tutoring_request($1, true)`, [r1]), 'NOT_ALLOWED');
const cq = await rows(`select * from public.managed_tutoring_requests($1, 7)`, [D]);
// 20261112120000 sonrası koç talepleri görmez (soru çözümü öğretmen ve müdür işi).
check(cq.length === 0, 'koç talepleri görmez', cq.map((c) => c.student_name));
await asUser(A.admin);
await expectError('müdür karar veremez',
  () => db.query(`select public.decide_tutoring_request($1, true)`, [r1]), 'NOT_ALLOWED');
check((await rows(`select * from public.managed_tutoring_requests($1, 7)`, [D])).length === 3, 'müdür kurumun bütün taleplerini görür');
await asUser(B.teacherUser);
await expectError('başka öğretmen karar veremez',
  () => db.query(`select public.decide_tutoring_request($1, true)`, [r1]), 'NOT_ALLOWED');
check((await rows(`select * from public.teacher_tutoring_requests($1, 7)`, [D])).length === 0, 'başka öğretmen talepleri görmez');

await asUser(A.teacherUser);
await db.query(`select public.decide_tutoring_request($1, true)`, [r1]);
await db.query(`select public.decide_tutoring_request($1, true)`, [r2]);
await expectError('kontenjan dolunca onay reddedilir',
  () => db.query(`select public.decide_tutoring_request($1, true)`, [r3]), 'TUTOR_SESSION_FULL');
await db.query(`select public.decide_tutoring_request($1, false, '  Bu hafta dolu  ')`, [r3]);
await expectError('karar verilmiş talebe ikinci karar yok',
  () => db.query(`select public.decide_tutoring_request($1, true)`, [r3]), 'TUTOR_ALREADY_DECIDED');

await asSuper();
const sn = await rows(`select user_id, data from public.notifications where kind = 'tutoring_request' and user_id in ($1, $2) order by created_at`, [A.s1, A.s3]);
check(sn.some((n) => n.user_id === A.s1 && n.data.event === 'approved' && n.data.teacher === 'Bal Akademi Selin'),
  'öğrenciye onay bildirimi', sn);
check(sn.some((n) => n.user_id === A.s3 && n.data.event === 'rejected' && n.data.reason === 'Bu hafta dolu'),
  'öğrenciye ret bildirimi ve gerekçe', sn);

await asUser(A.s1);
const my = await rows(`select * from public.my_tutoring_requests()`);
check(my.length === 1 && my[0].status === 'approved', 'öğrenci kendi talebini onaylı görür', my);
const after = await rows(`select * from public.open_tutoring_sessions($1, 1)`, [D]);
const s1row = after.find((o) => o.session_id === sess.id);
check(s1row?.taken === 2 && s1row.my_status === 'approved', 'dolu kontenjan ve kendi durumu', s1row);
await asUser(A.s3);
await expectError('dolu oturuma yeni talep reddedilir',
  () => db.query(`select public.request_tutoring_session($1, $2)`, [sess.id, D]), 'TUTOR_SESSION_FULL');

console.log('İptal ve günlük sınır');
await asUser(A.s1);
await db.query(`select public.cancel_tutoring_request($1)`, [r1]);
check((await rows(`select * from public.my_tutoring_requests()`)).length === 0, 'iptal edilen listeden düşer');
await asUser(A.s2);
await expectError('başkasının talebini iptal edemez',
  () => db.query(`select public.cancel_tutoring_request($1)`, [r1]), 'NOT_ALLOWED');
await asUser(A.admin);
const extra = [];
for (const [s, e] of [['18:00', '18:30'], ['19:00', '19:30'], ['20:00', '20:30']]) {
  extra.push((await one(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time, capacity) values ($1, $2, $3, $4, 5) returning id`,
    [A.teacher, DOW, s, e])).id);
}
await asUser(A.s3);
await db.query(`select public.request_tutoring_session($1, $2)`, [priv.id, D]);
await db.query(`select public.request_tutoring_session($1, $2)`, [extra[0], D]);
await db.query(`select public.request_tutoring_session($1, $2)`, [extra[1], D]);
await expectError('günde 3 etkin talepten fazlası reddedilir',
  () => db.query(`select public.request_tutoring_session($1, $2)`, [extra[2], D]), 'TUTOR_DAILY_LIMIT');

console.log('Öğretmen birleştirilince oturumlar kalır');
await asUser(A.admin);
const manual = (await one(`insert into public.teachers (full_name, branches) values ('Bal Akademi Selin', '{Matematik}') returning id`)).id;
await db.query(`select public.merge_teachers($1, $2)`, [manual, A.teacher]);
await asSuper();
const moved = await one(`select count(*)::int n from public.tutoring_sessions where teacher_id = $1`, [manual]);
check(moved.n === 5, 'oturumlar elle eklenen satıra taşındı', moved);
const keptReq = await one(`select count(*)::int n from public.tutoring_requests where session_id = $1`, [sess.id]);
check(keptReq.n === 3, 'talepler korundu', keptReq);

console.log('Geri alma ve yeniden uygulama');
await asSuper();
await db.exec(read(rbDir, '20261111120000_tutoring_sessions.down.sql'));
const gone = await one(`select to_regclass('public.tutoring_sessions') t, to_regclass('public.tutoring_requests') r`);
check(gone.t === null && gone.r === null, 'tablolar silindi', gone);
await db.exec(read(migDir, '20261111120000_tutoring_sessions.sql'));
check((await one(`select to_regclass('public.tutoring_sessions') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} test başarısız` : '\nHepsi geçti');
process.exit(failures ? 1 : 0);
