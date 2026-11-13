// Öğretmen rolü (20261111100000_teacher_role_enum + 20261111110000_teacher_role):
// müdür daveti, kayıtta otomatik teachers satırı, öğretmenin kendi kaydı ve
// programı, elle eklenmiş öğretmenle birleştirme, geri alma.
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
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const student = await signUp((await one(`select public.create_invite('student') c`)).c, `${name} Öğrenci`);
  return { org, admin, coach, student };
}
const credits = async (org) => {
  await asSuper();
  return Number((await one(`select credit_balance from public.organizations where id = $1`, [org])).credit_balance);
};

const A = await school('Bal Akademi', 'ADMINTR1');
const B = await school('Arı Kurs', 'ADMINTR2');

console.log('Davet');
await asUser(A.admin);
const tCode = (await one(`select public.create_invite('teacher', null, 5) c`)).c;
check(typeof tCode === 'string' && tCode.length === 8, 'müdür öğretmen daveti oluşturur', tCode);
await asUser(A.coach);
await expectError('koç öğretmen daveti oluşturamaz',
  () => db.query(`select public.create_invite('teacher')`), 'NOT_ALLOWED');
await asUser(A.student);
await expectError('öğrenci öğretmen daveti oluşturamaz',
  () => db.query(`select public.create_invite('teacher')`), 'NOT_ALLOWED');
await asSuper();
const info = await one(`select public.check_invite($1) i`, [tCode]);
check(info.i?.role === 'teacher', 'check_invite rolü teacher döner', info);

console.log('Kayıt: teachers listesine kendiliğinden');
const before = await credits(A.org);
const selin = await signUp(tCode, 'Selin Kaya', { teacher_branches: [' Matematik ', 'Geometri', 'Matematik', ''] });
await asSuper();
const selinProfile = await one(`select role, org_id from public.profiles where id = $1`, [selin]);
check(selinProfile.role === 'teacher' && selinProfile.org_id === A.org, 'profil teacher rolüyle kurumda', selinProfile);
const selinRow = await one(`select * from public.teachers where profile_id = $1`, [selin]);
check(selinRow && selinRow.org_id === A.org && selinRow.full_name === 'Selin Kaya',
  'teachers satırı açıldı', selinRow);
check(JSON.stringify(selinRow?.branches) === JSON.stringify(['Matematik', 'Geometri']),
  'branşlar kırpıldı, tekilleşti', selinRow?.branches);
check((await credits(A.org)) === before, 'öğretmen kaydı kredi harcamaz');

const mert = await signUp(tCode, 'Mert Can');
await asSuper();
const mertRow = await one(`select branches from public.teachers where profile_id = $1`, [mert]);
check(JSON.stringify(mertRow?.branches) === JSON.stringify(['Genel']), 'branş yoksa Genel', mertRow);
const used = await one(`select used_count from public.invite_codes where code = $1`, [tCode]);
check(used.used_count === 2, 'davet hakkı düştü', used);

console.log('Öğretmenin kendi kaydı');
await asUser(selin);
const me = await one(`select * from public.my_teacher()`);
check(me?.id === selinRow.id && me.org_name === 'Bal Akademi', 'my_teacher kendi satırı', me);
const nb = await one(`select public.set_my_teacher_branches(array['Fizik', ' Fizik ', 'Kimya']) b`);
check(JSON.stringify(nb.b) === JSON.stringify(['Fizik', 'Kimya']), 'branşını kendisi değiştirir', nb);
await expectError('boş branş reddedilir',
  () => db.query(`select public.set_my_teacher_branches(array['  '])`), 'BRANCH_REQUIRED');
await asSuper();
const mertAfter = await one(`select branches from public.teachers where profile_id = $1`, [mert]);
check(JSON.stringify(mertAfter.branches) === JSON.stringify(['Genel']), 'başka öğretmenin branşı değişmedi', mertAfter);
await asUser(A.coach);
await expectError('koç set_my_teacher_branches çağıramaz',
  () => db.query(`select public.set_my_teacher_branches(array['Fizik'])`), 'NOT_ALLOWED');

await asUser(selin);
await expectError('öğretmen teachers tablosuna doğrudan yazamaz',
  () => db.query(`insert into public.teachers (full_name, branches) values ('X', '{A}')`));
const seen = await rows(`select id from public.teachers`);
check(seen.length === 0, 'öğretmen teachers tablosunu doğrudan okuyamaz (yalnızca my_teacher)', seen);
const ups = await rows(`update public.teachers set full_name = 'Y' where profile_id = $1 returning id`, [selin]);
check(ups.length === 0, 'öğretmen kendi satırını doğrudan güncelleyemez', ups);
const fin = await rows(`select id from public.finance_expenses`);
check(fin.length === 0, 'öğretmen finansı görmez', fin);
const studs = await rows(`select id from public.profiles where role = 'student'`);
check(studs.length === 0, 'öğretmen öğrenci profillerini görmez', studs);

console.log('Öğretmenin programı');
await asUser(A.admin);
const slot = (await one(`insert into public.time_slots (day, seq, start_time, end_time) values (1, 1, '09:00', '09:40') returning id`)).id;
const slot2 = (await one(`insert into public.time_slots (day, seq, start_time, end_time) values (1, 2, '09:50', '10:30') returning id`)).id;
const klass = (await one(`insert into public.classrooms (name) values ('12-A') returning id`)).id;
const klass2 = (await one(`insert into public.classrooms (name) values ('12-B') returning id`)).id;
const sch = (await one(`insert into public.schedules (name) values ('Güz') returning id`)).id;
await db.query(`insert into public.schedule_entries (schedule_id, teacher_id, classroom_id, time_slot_id, branch)
  values ($1, $2, $3, $4, 'Fizik')`, [sch, selinRow.id, klass, slot]);
await db.query(`select public.publish_schedule($1)`, [sch]);
await asUser(selin);
const tt = await rows(`select * from public.my_timetable()`);
check(tt.length === 1 && tt[0].classroom_name === '12-A' && tt[0].student_id === null,
  'öğretmen yayındaki kendi dersini görür', tt);
await asUser(mert);
check((await rows(`select * from public.my_timetable()`)).length === 0, 'öteki öğretmen görmez');

console.log('Birleştirme');
await asUser(A.admin);
const ayseManual = (await one(`insert into public.teachers (full_name, branches) values ('Ayşe Demir', '{Biyoloji}') returning id`)).id;
await db.query(`insert into public.schedule_entries (schedule_id, teacher_id, classroom_id, time_slot_id, branch)
  values ($1, $2, $3, $4, 'Biyoloji')`, [sch, ayseManual, klass2, slot]);
await db.query(`insert into public.teacher_pay_rates (teacher_id, pay_type, amount) values ($1, 'hourly', 400)`, [ayseManual]);
await db.query(`insert into public.teacher_availability (teacher_id, day, start_time, end_time) values ($1, 1, '09:00', '12:00')`, [ayseManual]);
const tCode2 = (await one(`select public.create_invite('teacher') c`)).c;
const ayse = await signUp(tCode2, 'Ayşe Demir', { teacher_branches: ['Biyoloji', 'Kimya'] });
await asSuper();
const ayseAuto = (await one(`select id from public.teachers where profile_id = $1`, [ayse])).id;
await db.query(`insert into public.teacher_availability (org_id, tenant_id, teacher_id, day, start_time, end_time)
  select org_id, tenant_id, id, 2, '10:00', '11:00' from public.teachers where id = $1`, [ayseAuto]);

await asUser(B.admin);
await expectError('başka kurumun müdürü birleştiremez',
  () => db.query(`select public.merge_teachers($1, $2)`, [ayseManual, ayseAuto]), 'NOT_ALLOWED');
await asUser(selin);
await expectError('öğretmen birleştiremez',
  () => db.query(`select public.merge_teachers($1, $2)`, [ayseManual, ayseAuto]), 'NOT_ALLOWED');
await asUser(A.admin);
await expectError('ters çift reddedilir',
  () => db.query(`select public.merge_teachers($1, $2)`, [ayseAuto, ayseManual]), 'TEACHER_MERGE_BAD_PAIR');
await db.query(`select public.merge_teachers($1, $2)`, [ayseManual, ayseAuto]);
const merged = await one(`select * from public.teachers where id = $1`, [ayseManual]);
check(merged.profile_id === ayse, 'elle eklenen satır hesaba bağlandı', merged);
check(JSON.stringify(merged.branches) === JSON.stringify(['Biyoloji', 'Kimya']), 'branşlar birleşti', merged.branches);
check(!(await one(`select 1 x from public.teachers where id = $1`, [ayseAuto])), 'otomatik satır silindi');
const rate = await one(`select amount from public.teacher_pay_rates where teacher_id = $1`, [ayseManual]);
check(Number(rate?.amount) === 400, 'ücret kaydı korundu', rate);
const av = await rows(`select day from public.teacher_availability where teacher_id = $1`, [ayseManual]);
check(av.length === 1 && av[0].day === 1, 'elle girilen müsaitlik kaldı', av);
await asUser(ayse);
const tt2 = await rows(`select * from public.my_timetable()`);
check(tt2.length === 1 && tt2[0].branch === 'Biyoloji', 'birleşince öğretmen eski dersini görür', tt2);

console.log('Birleştirme çakışması');
await asUser(A.admin);
const canManual = (await one(`insert into public.teachers (full_name, branches) values ('Can Er', '{Tarih}') returning id`)).id;
await db.query(`insert into public.schedule_entries (schedule_id, teacher_id, classroom_id, time_slot_id, branch)
  values ($1, $2, $3, $4, 'Tarih')`, [sch, canManual, klass, slot2]);
const can = await signUp((await (async () => { await asUser(A.admin); return (await one(`select public.create_invite('teacher') c`)).c; })()), 'Can Er');
await asSuper();
const canAuto = (await one(`select id from public.teachers where profile_id = $1`, [can])).id;
await db.query(`insert into public.schedule_entries (org_id, tenant_id, schedule_id, teacher_id, classroom_id, time_slot_id, branch)
  select org_id, tenant_id, $1, $2, $3, $4, 'Tarih' from public.teachers where id = $2`, [sch, canAuto, klass2, slot2]);
await asUser(A.admin);
await expectError('aynı saatte iki dersi olan çift birleşmez',
  () => db.query(`select public.merge_teachers($1, $2)`, [canManual, canAuto]), 'TEACHER_MERGE_CONFLICT');
await asSuper();
check(!!(await one(`select 1 x from public.teachers where id = $1`, [canAuto])), 'çakışmada hiçbir şey silinmedi');

console.log('Bayrak işlem dışına sızmaz');
await asUser(A.admin);
await asUser(selin);
await expectError('kayıttan sonra öğretmen doğrudan teachers ekleyemez',
  () => db.query(`insert into public.teachers (org_id, full_name, branches) values ($1, 'Z', '{A}')`, [A.org]));

console.log('Geri alma ve yeniden uygulama');
await asSuper();
await db.exec(read(rbDir, '20261111110000_teacher_role.down.sql'));
await db.exec(read(rbDir, '20261111100000_teacher_role_enum.down.sql'));
await asUser(A.admin);
await expectError('geri alınınca öğretmen daveti yok',
  () => db.query(`select public.create_invite('teacher')`), 'NOT_ALLOWED');
await asSuper();
const fn = await one(`select count(*)::int n from pg_proc where proname in ('my_teacher', 'merge_teachers', 'set_my_teacher_branches', 'clean_teacher_branches')`);
check(fn.n === 0, 'yeni fonksiyonlar silindi', fn);
await db.exec(read(migDir, '20261111100000_teacher_role_enum.sql'));
await db.exec(read(migDir, '20261111110000_teacher_role.sql'));
await asUser(A.admin);
check(!!(await one(`select public.create_invite('teacher') c`)).c, 'yeniden uygulanınca davet çalışır');

console.log(failures ? `\n${failures} test başarısız` : '\nHepsi geçti');
process.exit(failures ? 1 : 0);
