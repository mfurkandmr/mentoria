// Sınıf yönetimi ve öğrenci kayıt modları (20261105140000_student_registry).
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

const A = await school('Bal Akademi', 'ADMINSR1');
const B = await school('Arı Kurs', 'ADMINSR2');
await asSuper();
const orgCode = async (org) => {
  await asSuper();
  await db.query(`update public.organizations set invite_code = $2 where id = $1`, [org, `MENTORIA-${org.slice(0, 6).toUpperCase()}`]);
  return `MENTORIA-${org.slice(0, 6).toUpperCase()}`;
};
const codeA = await orgCode(A.org);
const trySignUp = async (code, name, number) => {
  try { return await signUp(code, name, { student_number: number }); }
  catch (e) { return e.message; }
};

console.log('Kayıt modu ve sınıf');
await asUser(A.admin);
check((await one(`select student_registration_mode m from public.organizations where id = $1`, [A.org])).m === 'free',
  'varsayılan mod serbest');
const say = await one(`insert into public.classrooms (name) values ('Sayısal-1') returning id`);
const ea = await one(`insert into public.classrooms (name, capacity) values ('EA-1', 25) returning id`);

console.log('Mod B (serbest)');
await asAnon();
check((await one(`select public.match_student_number($1, '1001') r`, [codeA])).r === 'ok', 'serbest: numara uygun');
check((await one(`select public.match_student_number($1, '12a') r`, [codeA])).r === 'invalid', 'rakam dışı numara geçersiz');
const free1 = await signUp(codeA, 'Serbest Öğrenci', { student_number: '1001' });
let p = await one(`select * from public.profiles where id = $1`, [free1]);
check(p.student_number === '1001' && p.registration_source === 'free' && p.number_flag === null,
  'serbest kayıt numarayla tamam', p);
const dup = await signUp(codeA, 'Tekrar Öğrenci', { student_number: '1001' });
p = await one(`select * from public.profiles where id = $1`, [dup]);
check(p.student_number === null && p.number_flag === 'duplicate' && p.attempted_number === '1001',
  'mükerrer numara: kayıt olur, numarasız ve şüpheli', p);
const badNo = await signUp(codeA, 'Harfli Öğrenci', { student_number: '12AB' });
p = await one(`select * from public.profiles where id = $1`, [badNo]);
check(p.number_flag === 'bad_format' && p.student_number === '12AB', 'harfli numara şüpheli işaretlenir', p);
await asAnon();
check((await one(`select public.match_student_number($1, '1001') r`, [codeA])).r === 'taken', 'kullanılan numara: taken');

console.log('Öğrenci kendi numarasını değiştiremez');
await asUser(free1);
await expectError('öğrenci numarasını güncelleyemez', () =>
  db.query(`update public.profiles set student_number = '9' where id = $1`, [free1]), 'permission');
await expectError('öğrenci set_student_number çağıramaz', () =>
  db.query(`select public.set_student_number($1, '9')`, [free1]), 'NOT_ALLOWED');

console.log('Mod A (liste)');
await asUser(A.admin);
const imp = (await one(`select public.import_expected_students($1) r`, [JSON.stringify([
  { number: '2001', name: 'Liste Öğrenci', class: 'sayısal-1', phone: '+905321112233' },
  { number: '2002', name: 'Bekleyen Öğrenci' },
  { number: '1001', name: 'Serbest Öğrenci' },
])])).r;
check(imp.inserted === 3, 'liste yüklendi', imp);
await expectError('liste satırı denetlenir', () =>
  db.query(`select public.import_expected_students($1)`, [JSON.stringify([{ number: 'x1', name: 'A B' }])]), 'BAD_ROW');
await db.query(`select public.set_registration_mode('list')`);
const flags = await rows(`select full_name, number_flag from public.profiles where org_id = $1 and role = 'student' order by full_name`, [A.org]);
check(flags.find((f) => f.full_name === 'Serbest Öğrenci').number_flag === null
  && flags.find((f) => f.full_name === 'Harfli Öğrenci').number_flag === 'bad_format',
  'listeye geçince listede olan temiz kalır', flags);
check(flags.find((f) => f.full_name === `Bal Akademi Öğrenci`).number_flag === 'not_in_list',
  'numarası listede olmayan şüpheli olur', flags);
check((await one(`select status from public.expected_students where student_number = '1001'`)).status === 'matched',
  'mevcut öğrenci listeyle eşleşti');

await asAnon();
check((await one(`select public.match_student_number($1, '9999') r`, [codeA])).r === 'not_found', 'listede yok: not_found');
check((await one(`select public.match_student_number($1, '2001') r`, [codeA])).r === 'ok', 'listede var: ok');
const r1 = await trySignUp(codeA, 'Yanlış Numara', '9999');
check(typeof r1 === 'string' && r1.includes('STUDENT_NUMBER_NOT_FOUND'), 'listede olmayan numarayla kayıt reddedilir', r1);
const r2 = await trySignUp(codeA, 'Numarasız', '');
check(typeof r2 === 'string' && r2.includes('STUDENT_NUMBER_REQUIRED'), 'liste modunda numara zorunlu', r2);
const matched = await signUp(codeA, 'Başka Ad Yazdı', { student_number: '2001' });
p = await one(`select * from public.profiles where id = $1`, [matched]);
check(p.full_name === 'Liste Öğrenci' && p.student_number === '2001' && p.registration_source === 'matched',
  'listedeki numarayla kayıt: ad listeden', p);
check((await one(`select classroom_id from public.classroom_students where student_id = $1`, [matched]))?.classroom_id === say.id,
  'sınıf adı listeden eşleşti (büyük/küçük harf duyarsız)');
check((await one(`select phone from public.student_guardian_phones where student_id = $1`, [matched]))?.phone === '+905321112233',
  'veli telefonu listeden geldi');
const r3 = await trySignUp(codeA, 'İkinci Kez', '2001');
check(typeof r3 === 'string' && r3.includes('STUDENT_NUMBER_TAKEN'), 'aynı numarayla ikinci kayıt reddedilir', r3);
await asAnon();
check((await one(`select public.match_student_number($1, '2001') r`, [codeA])).r === 'taken', 'eşleşen numara: taken');

console.log('Liste gizli');
for (const [who, n] of [[matched, 'öğrenci'], [A.coach, 'koç'], [A.parent, 'veli'], [B.admin, 'öteki müdür']]) {
  await asUser(who);
  check((await rows(`select id from public.expected_students`)).length === 0, `${n} beklenen listeyi okuyamaz`);
}
await asAnon();
await expectError('anonim listeyi okuyamaz', () => db.query(`select id from public.expected_students`), 'permission');

console.log('Atama, geçmiş, koç');
await asUser(A.admin);
const all = await rows(`select * from public.managed_students_list()`);
check(all.length === 5, 'müdür kurumun bütün öğrencilerini görür', all.length);
const unassigned = all.filter((s) => !s.classroom_id).map((s) => s.student_id);
check(unassigned.length === 4, 'sınıfı olmayan 4 öğrenci');
await asUser(A.coach);
const mine = await rows(`select * from public.managed_students_list()`);
check(mine.length === 5, 'koç (kurum kodu en az öğrencili koça bağladı) kendi öğrencilerini görür', mine.length);
check((await one(`select public.assign_students_to_class($1, $2) n`, [unassigned, ea.id])).n === 4, 'koç toplu atar');
await db.query(`select public.assign_students_to_class($1, $2)`, [[matched], ea.id]);
const hist = await rows(`select * from public.student_class_history where student_id = $1 order by changed_at`, [matched]);
check(hist.length === 2 && hist[1].old_name === 'Sayısal-1' && hist[1].new_name === 'EA-1' && hist[1].changed_role === 'coach',
  'sınıf değişikliği geçmişe yazıldı', hist);
check((await rows(`select id from public.classrooms`)).length === 2, 'koç kurumun sınıflarını okur');
await expectError('koç sınıf oluşturamaz', () => db.query(`insert into public.classrooms (name) values ('X')`), 'TIMETABLE_NOT_ADMIN');
await db.query(`select public.set_student_number($1, ' 3005 ')`, [dup]);
p = await one(`select student_number, number_flag, attempted_number from public.profiles where id = $1`, [dup]);
check(p.student_number === '3005' && p.number_flag === null && p.attempted_number === null,
  'koç numarayı düzeltir, işaret kalkar', p);
check((await one(`select new_number, changed_role from public.student_number_history where student_id = $1`, [dup])).new_number === '3005',
  'numara değişikliği geçmişe yazıldı');
await expectError('numara yalnızca rakam', () => db.query(`select public.set_student_number($1, '12A')`, [dup]), 'INVALID_NUMBER');
await expectError('numara benzersiz', () => db.query(`select public.set_student_number($1, '2001')`, [dup]), 'NUMBER_TAKEN');
check((await one(`select public.student_number_available($1, '2001') a`, [dup])).a === false, 'anlık kontrol: dolu');
check((await one(`select public.student_number_available($1, '4444') a`, [dup])).a === true, 'anlık kontrol: boş');
await db.query(`select public.clear_number_flag($1)`, [badNo]);
check((await one(`select number_flag from public.profiles where id = $1`, [badNo])).number_flag === null, 'şüpheli işareti kaldırılır');
await expectError('koç öğrencinin koçunu değiştiremez', () =>
  db.query(`select public.set_student_coach($1, $2)`, [dup, A.coach]), 'NOT_ALLOWED');

await asUser(B.coach);
check((await rows(`select * from public.managed_students_list()`)).every((s) => s.student_id !== matched),
  'öteki kurumun koçu öğrenciyi görmez');
await expectError('öteki koç atayamaz', () =>
  db.query(`select public.assign_students_to_class($1, $2)`, [[matched], ea.id]), 'TIMETABLE_BAD_REF');
await asUser(B.admin);
const bClass = await one(`insert into public.classrooms (name) values ('B-1') returning id`);
await expectError('öteki müdür kendi sınıfına bu öğrenciyi atayamaz', () =>
  db.query(`select public.assign_students_to_class($1, $2)`, [[matched], bClass.id]), 'NOT_ALLOWED');

await asUser(A.admin);
await expectError('içinde öğrenci olan sınıf silinemez', () =>
  db.query(`delete from public.classrooms where id = $1`, [ea.id]), 'CLASSROOM_NOT_EMPTY');
await db.query(`update public.classrooms set active = false where id = $1`, [say.id]);
await expectError('pasif sınıfa atanamaz', () =>
  db.query(`select public.assign_students_to_class($1, $2)`, [[matched], say.id]), 'TIMETABLE_BAD_REF');
await db.query(`delete from public.classrooms where id = $1`, [say.id]);
check((await rows(`select id from public.classrooms where id = $1`, [say.id])).length === 0, 'boş sınıf silinir');

console.log('Program görünümü ve bildirim');
await asUser(A.admin);
const t1 = await one(`insert into public.teachers (full_name, branches, profile_id) values ('Ahmet Hoca', '{Matematik}', $1) returning id`, [A.coach]);
const slot = await one(`insert into public.time_slots (day, seq, start_time, end_time) values (1, 1, '09:00', '09:40') returning id`);
const sch = await one(`insert into public.schedules (name) values ('Güz') returning id`);
await db.query(`select public.save_schedule_entries($1, $2)`, [sch.id, JSON.stringify([
  { teacher_id: t1.id, classroom_id: ea.id, time_slot_id: slot.id, branch: 'Matematik' }])]);
const reach = (await one(`select public.schedule_reach($1) r`, [sch.id])).r;
check(reach.classes === 1 && reach.students === 5, 'yayın öncesi etkilenecek sınıf / öğrenci', reach);
await asUser(matched);
check((await rows(`select * from public.my_timetable()`)).length === 0, 'taslak program öğrenciye dönmez');
check((await one(`select classroom_name from public.my_classroom()`)).classroom_name === 'EA-1', 'öğrenci sınıfını görür');
await asUser(A.admin);
await db.query(`select public.publish_schedule($1)`, [sch.id]);
check((await one(`select published_at from public.schedules where id = $1`, [sch.id])).published_at !== null, 'yayın tarihi yazıldı');
await asSuper();
const notes = await rows(`select user_id, data from public.notifications where kind = 'timetable'`);
check(notes.length === 6 && notes.some((n) => n.user_id === A.coach && n.data.route === '/coach')
  && notes.some((n) => n.user_id === matched && n.data.route === '/student/timetable'),
  'yayınlanınca öğrencilere ve bağlı öğretmene bildirim', notes.length);
await asUser(A.admin);
await db.query(`select public.save_schedule_entries($1, $2)`, [sch.id, JSON.stringify([
  { teacher_id: t1.id, classroom_id: ea.id, time_slot_id: slot.id, branch: 'Matematik' }])]);
await asSuper();
check((await one(`select count(*)::int c from public.notifications where kind = 'timetable'`)).c === 6,
  'yayındaki program hemen yeniden kaydedilince tekrar bildirim yok');
await asUser(matched);
check((await rows(`select * from public.my_timetable()`)).length === 1, 'yayındaki program öğrenciye döner');
await asUser(A.admin);
await db.query(`select public.assign_students_to_class($1, null)`, [[matched]]);
await asUser(matched);
check((await rows(`select * from public.my_timetable()`)).length === 0, 'sınıftan çıkınca program görünmez');
check((await rows(`select * from public.my_classroom()`)).length === 0, 'sınıf yok');

console.log('Geri alma ve yeniden uygulama');
await asSuper();
const name = '20261105140000_student_registry';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.expected_students') t`)).t === null, 'liste tablosu kaldırıldı');
check((await one(`select count(*)::int c from information_schema.columns where table_name = 'profiles' and column_name = 'number_flag'`)).c === 0,
  'profil sütunları kaldırıldı');
const after = await signUp(codeA, 'Geri Alma Sonrası', {});
check(!!after, 'eski kayıt fonksiyonu çalışıyor');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select to_regclass('public.expected_students') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
