// Otomatik ders programı (20261105130000_timetable).
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

const A = await school('Bal Akademi', 'ADMINTT1');
const B = await school('Arı Kurs', 'ADMINTT2');

console.log('Kurulum (müdür)');
await asUser(A.admin);
const room = await one(`insert into public.rooms (name, capacity) values ('D-1', 30) returning *`);
check(room.org_id === A.org && room.tenant_id, 'derslik: kurum sunucuda yazılır', room);
const t1 = await one(`insert into public.teachers (full_name, branches, max_weekly_hours, profile_id)
  values ('  Ahmet Hoca ', '{Matematik}', 20, $1) returning *`, [A.coach]);
check(t1.full_name === 'Ahmet Hoca' && t1.org_id === A.org, 'öğretmen eklendi (koç hesabına bağlı)', t1);
await expectError('öğretmen başka kurumun koçuna bağlanamaz', () =>
  db.query(`insert into public.teachers (full_name, branches, profile_id) values ('X', '{Fizik}', $1)`, [B.coach]),
  'TIMETABLE_BAD_REF');
await db.query(`insert into public.teacher_availability (teacher_id, day, start_time, end_time)
  values ($1, 2, '09:00', '13:00')`, [t1.id]);
const cls = await one(`insert into public.classrooms (name, level, field, home_room_id)
  values ('Sayısal-1', '12', 'SAY', $1) returning *`, [room.id]);
await db.query(`insert into public.classroom_students (classroom_id, student_id) values ($1, $2)`, [cls.id, A.student]);
await expectError('sınıfa veli eklenemez', () =>
  db.query(`insert into public.classroom_students (classroom_id, student_id) values ($1, $2)`, [cls.id, A.parent]),
  'TIMETABLE_BAD_REF');
const [s1, s2] = (await rows(`insert into public.time_slots (day, seq, start_time, end_time)
  values (2, 1, '09:00', '09:40'), (2, 2, '09:50', '10:30') returning id`)).map((r) => r.id);
await expectError('aynı gün aynı sıra iki kez olmaz', () =>
  db.query(`insert into public.time_slots (day, seq, start_time, end_time) values (2, 1, '11:00', '11:40')`), 'unique');
await db.query(`insert into public.class_lessons (classroom_id, branch, weekly_hours, teacher_id)
  values ($1, 'Matematik', 2, $2)`, [cls.id, t1.id]);
const sch = await one(`insert into public.schedules (name, term) values ('Güz', '2026-2027') returning *`);
check(sch.status === 'draft', 'program taslak başlar');

console.log('Program kaydı ve çakışmalar');
const entries = [
  { teacher_id: t1.id, classroom_id: cls.id, room_id: room.id, time_slot_id: s1, branch: 'Matematik', locked: true },
  { teacher_id: t1.id, classroom_id: cls.id, room_id: room.id, time_slot_id: s2, branch: 'Matematik' },
];
check((await one(`select public.save_schedule_entries($1, $2, 42) n`, [sch.id, JSON.stringify(entries)])).n === 2,
  'program tek seferde yazılır');
check((await one(`select soft_score from public.schedules where id = $1`, [sch.id])).soft_score === 42, 'skor kaydedildi');
await expectError('öğretmen aynı saatte iki derste olamaz', () =>
  db.query(`insert into public.schedule_entries (schedule_id, teacher_id, classroom_id, time_slot_id, branch)
    values ($1, $2, $3, $4, 'Matematik')`, [sch.id, t1.id, cls.id, s1]), 'unique');
const cls2 = await one(`insert into public.classrooms (name) values ('EA-1') returning id`);
await expectError('derslik aynı saatte iki sınıfa verilemez', () =>
  db.query(`insert into public.schedule_entries (schedule_id, teacher_id, classroom_id, room_id, time_slot_id, branch)
    values ($1, (select id from public.teachers where full_name = 'Ahmet Hoca'), $2, $3, $4, 'Türkçe')`,
  [sch.id, cls2.id, room.id, s1]), 'unique');

console.log('Yalıtım');
await asUser(B.admin);
check((await rows(`select id from public.teachers`)).length === 0, 'öteki müdür öğretmenleri görmez');
await expectError('öteki müdür bu programa yazamaz', () =>
  db.query(`select public.save_schedule_entries($1, '[]')`, [sch.id]), 'TIMETABLE_NOT_ADMIN');
await expectError('öteki müdür bu öğretmene müsaitlik ekleyemez', () =>
  db.query(`insert into public.teacher_availability (teacher_id, day, start_time, end_time) values ($1, 1, '09:00', '10:00')`, [t1.id]),
  'TIMETABLE_NOT_ADMIN');
const bRoom = await one(`insert into public.rooms (name) values ('B-1') returning id`);
await asUser(A.admin);
await expectError('başka kurumun dersliği bağlanamaz', () =>
  db.query(`update public.classrooms set home_room_id = $1 where id = $2`, [bRoom.id, cls.id]), 'TIMETABLE_BAD_REF');
for (const [who, n] of [[A.coach, 'koç'], [A.student, 'öğrenci'], [A.parent, 'veli']]) {
  await asUser(who);
  check((await rows(`select id from public.schedule_entries`)).length === 0, `${n} tabloları doğrudan görmez`);
  await expectError(`${n} öğretmen ekleyemez`, () =>
    db.query(`insert into public.teachers (full_name, branches) values ('X', '{Fizik}')`), 'TIMETABLE_NOT_ADMIN');
}

console.log('Yayın ve görünüm');
await asUser(A.student);
check((await rows(`select * from public.my_timetable()`)).length === 0, 'taslak program öğrenciye görünmez');
await asUser(A.coach);
await expectError('koç yayınlayamaz', () => db.query(`select public.publish_schedule($1)`, [sch.id]), 'TIMETABLE_NOT_ADMIN');
await asUser(A.admin);
const old = await one(`insert into public.schedules (name, status) values ('Eski', 'published') returning id`);
await db.query(`select public.publish_schedule($1)`, [sch.id]);
const st = await rows(`select id, status from public.schedules order by name`);
check(st.find((s) => s.id === sch.id).status === 'published' && st.find((s) => s.id === old.id).status === 'draft',
  'yayınlanınca eski program taslağa döner', st);
await expectError('iki program birden yayında olamaz', () =>
  db.query(`update public.schedules set status = 'published' where id = $1`, [old.id]), 'unique');
await asUser(A.student);
let tt = await rows(`select * from public.my_timetable()`);
check(tt.length === 2 && tt[0].branch === 'Matematik' && tt[0].teacher_name === 'Ahmet Hoca'
  && tt[0].classroom_name === 'Sayısal-1' && tt[0].room_name === 'D-1' && tt[0].student_id === A.student,
  'öğrenci sınıfının programını görür', tt);
await asUser(A.parent);
tt = await rows(`select * from public.my_timetable()`);
check(tt.length === 2 && tt[0].student_id === A.student, 'veli çocuğunun programını görür', tt);
await asUser(A.coach);
tt = await rows(`select * from public.my_timetable()`);
check(tt.length === 2 && tt[0].student_id === null, 'öğretmen (koç hesabı) kendi derslerini görür', tt);
await asUser(B.coach);
check((await rows(`select * from public.my_timetable()`)).length === 0, 'öteki kurumun koçu görmez');
await asAnon();
await expectError('anonim çağıramaz', () => db.query(`select * from public.my_timetable()`), 'permission');

console.log('Silme');
await asUser(A.admin);
await db.query(`delete from public.teachers where id = $1`, [t1.id]);
check((await rows(`select id from public.schedule_entries`)).length === 0, 'öğretmen silinince dersleri de silinir');

console.log('Geri alma ve yeniden uygulama');
await asSuper();
const name = '20261105130000_timetable';
// Sonraki migration'lar buna bağlı: ters sırayla geri al, sırayla uygula.
const later = migs.filter((f) => f > `${name}.sql`).map((f) => f.replace('.sql', '')).reverse();
for (const l of later) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.schedule_entries') t`)).t === null, 'tablolar kaldırıldı');
await db.exec(read(migDir, `${name}.sql`));
for (const l of [...later].reverse()) await db.exec(read(migDir, `${l}.sql`));
check((await one(`select to_regclass('public.schedule_entries') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
