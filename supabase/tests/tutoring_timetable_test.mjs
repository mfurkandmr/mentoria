// Soru çözümü ders programında (20261112120000_tutoring_timetable): koç
// talepleri görmez, derslik çakışması reddedilir, geri alma çalışır.
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

await asSuper();
const org = (await one(`insert into public.organizations (name, seat_limit) values ('Bal Akademi', 20) returning id`)).id;
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMINTT1', $1, 'admin')`, [org]);
const admin = await signUp('ADMINTT1', 'Müdür');
const coach = await signUp(await invite(admin, 'coach'), 'Koç');
const student = await signUp(await invite(coach, 'student'), 'Ali');
const t1User = await signUp(await invite(admin, 'teacher'), 'Selin', { teacher_branches: ['Matematik'] });
const t2User = await signUp(await invite(admin, 'teacher'), 'Mert', { teacher_branches: ['Fizik'] });
await asSuper();
const t1 = (await one(`select id from public.teachers where profile_id = $1`, [t1User])).id;
const t2 = (await one(`select id from public.teachers where profile_id = $1`, [t2User])).id;
const target = await one(`select (public.tr_now()::date + 2) d, extract(isodow from public.tr_now()::date + 2)::int dow`);
const D = target.d instanceof Date ? target.d.toISOString().slice(0, 10) : String(target.d);
const DOW = target.dow;

console.log('Derslik çakışması');
await asUser(admin);
const room = (await one(`insert into public.rooms (name) values ('D-1') returning id`)).id;
const sess = await one(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time, capacity, room_id)
  values ($1, $2, '15:00', '16:00', 4, $3) returning *`, [t1, DOW, room]);
check(sess.room_id === room, 'oturum dersliğe yazıldı');
await expectError('aynı derslikte aynı saatte ikinci oturum reddedilir',
  () => db.query(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time, room_id)
    values ($1, $2, '15:30', '16:30', $3)`, [t2, DOW, room]), 'TUTOR_ROOM_BUSY');
const other = await one(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time)
  values ($1, $2, '15:30', '16:30') returning id`, [t2, DOW]);
check(!!other.id, 'dersliksiz oturum aynı saatte açılır');
const slot = (await one(`insert into public.time_slots (day, seq, start_time, end_time) values ($1, 1, '09:00', '09:40') returning id`, [DOW])).id;
const klass = (await one(`insert into public.classrooms (name) values ('12-A') returning id`)).id;
const sch = (await one(`insert into public.schedules (name) values ('Güz') returning id`)).id;
await db.query(`insert into public.schedule_entries (schedule_id, teacher_id, classroom_id, time_slot_id, branch, room_id)
  values ($1, $2, $3, $4, 'Matematik', $5)`, [sch, t1, klass, slot, room]);
await db.query(`select public.publish_schedule($1)`, [sch]);
await expectError('yayındaki programda dersi olan dersliğe oturum açılamaz',
  () => db.query(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time, room_id)
    values ($1, $2, '09:10', '09:50', $3)`, [t2, DOW, room]), 'TUTOR_ROOM_BUSY');
const closed = await one(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time, room_id, active)
  values ($1, $2, '09:10', '09:50', $3, false) returning id`, [t2, DOW, room]);
check(!!closed.id, 'kapalı oturum çakışma sayılmaz');

console.log('Koç talepleri görmez');
await asUser(student);
await db.query(`select public.request_tutoring_session($1, $2, 'Türev')`, [sess.id, D]);
await asUser(coach);
check((await rows(`select * from public.managed_tutoring_requests($1, 7)`, [D])).length === 0, 'koç öğrencisinin talebini görmez');
await asUser(admin);
check((await rows(`select * from public.managed_tutoring_requests($1, 7)`, [D])).length === 1, 'müdür görür');
await asUser(t1User);
check((await rows(`select * from public.teacher_tutoring_requests($1, 7)`, [D])).length === 1, 'öğretmen görür');

console.log('Geri alma ve yeniden uygulama');
await asSuper();
await db.exec(read(rbDir, '20261112120000_tutoring_timetable.down.sql'));
await asUser(coach);
check((await rows(`select * from public.managed_tutoring_requests($1, 7)`, [D])).length === 1, 'geri alınınca koç yeniden görür');
await asUser(admin);
const back = await one(`insert into public.tutoring_sessions (teacher_id, day, start_time, end_time, room_id)
  values ($1, $2, '15:30', '16:30', $3) returning id`, [t2, (DOW % 7) + 1, room]).catch((e) => ({ error: e.message }));
check(!!back.id, 'geri alınınca derslik kontrolü yok', back);
await asSuper();
await db.exec(read(migDir, '20261112120000_tutoring_timetable.sql'));
await asUser(coach);
check((await rows(`select * from public.managed_tutoring_requests($1, 7)`, [D])).length === 0, 'yeniden uygulandı');

console.log(failures ? `\n${failures} test başarısız` : '\nHepsi geçti');
process.exit(failures ? 1 : 0);
