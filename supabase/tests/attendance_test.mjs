// Günlük yoklama ve gelmedi SMS (20261105120000_attendance).
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

const A = await school('Bal Akademi', 'ADMINAT1');
const B = await school('Arı Kurs', 'ADMINAT2');
await asSuper();
const today = (await one(`select (now() at time zone 'Europe/Istanbul')::date::text d`)).d;
// A kurumunda ikinci koç ve onun öğrencisi (A.coach yönetemez).
await asUser(A.admin);
const coach2 = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Bal Koç 2');
await asUser(coach2);
const other = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, 'Başka Öğrenci');

console.log('Yoklama listesi ve işaretleme');
await asUser(A.coach);
let list = await rows(`select * from public.attendance_day($1::date)`, [today]);
check(list.length === 1 && list[0].student_id === A.student && list[0].status === null,
  'koç yalnızca kendi öğrencisini görür, işaretsiz', list);
check(list[0].has_phone === false, 'veli telefonu yok');
check((await one(`select public.save_attendance($1::date, $2) n`, [today, { [A.student]: 'absent' }])).n === 1,
  'koç gelmedi işaretler');
await expectError('koç başka koçun öğrencisini işaretleyemez', () =>
  db.query(`select public.save_attendance($1::date, $2)`, [today, { [other]: 'present' }]), 'ATTENDANCE_NOT_MANAGER');
await expectError('veli hesabı yoklamaya giremez', () =>
  db.query(`select public.save_attendance($1::date, $2)`, [today, { [A.parent]: 'present' }]), 'ATTENDANCE_NOT_MANAGER');
await expectError('ileri tarih yok', () =>
  db.query(`select public.save_attendance($1::date + 1, $2)`, [today, { [A.student]: 'present' }]), 'ATTENDANCE_BAD_DATE');
await expectError('31 gün öncesi değiştirilemez', () =>
  db.query(`select public.save_attendance($1::date - 31, $2)`, [today, { [A.student]: 'present' }]), 'ATTENDANCE_BAD_DATE');
await expectError('geçersiz durum', () =>
  db.query(`select public.save_attendance($1::date, $2)`, [today, { [A.student]: 'sick' }]), 'ATTENDANCE_BAD_INPUT');
await expectError('tabloya doğrudan yazılamaz', () =>
  db.query(`update public.attendance set status = 'present'`), 'permission');

await asUser(A.admin);
list = await rows(`select * from public.attendance_day($1::date)`, [today]);
check(list.length === 2 && list.some((r) => r.student_id === A.student && r.status === 'absent'),
  'müdür kurumun bütün öğrencilerini görür (koç ve veli listede yok)', list);
await db.query(`select public.save_attendance($1::date, $2)`, [today, { [other]: 'late' }]);
check((await rows(`select id from public.attendance`)).length === 2, 'müdür her öğrenciyi işaretler');
await db.query(`select public.save_attendance($1::date, $2)`, [today, { [other]: null }]);
check((await rows(`select id from public.attendance`)).length === 1, 'işaret kaldırılır');
await db.query(`select public.save_attendance($1::date, $2)`, [today, { [other]: 'late' }]);

console.log('Veli telefonu');
await asUser(A.coach);
await expectError('telefon biçimi denetlenir', () =>
  db.query(`select public.set_guardian_phone($1, 'Ayşe', '05321234567')`, [A.student]), 'BAD_PHONE');
await expectError('koç başka öğrencinin velisini yazamaz', () =>
  db.query(`select public.set_guardian_phone($1, 'X', '+905321234567')`, [other]), 'ATTENDANCE_NOT_MANAGER');

console.log("Gelmedi SMS'i");
let res = (await one(`select public.send_absence_sms($1::date, $2) r`, [today, [A.student]])).r;
check(res.queued === 0 && res.no_phone === 1, 'telefonsuz öğrenci atlanır', res);
await db.query(`select public.set_guardian_phone($1, ' Ayşe Yılmaz ', '+905321234567')`, [A.student]);
list = await rows(`select * from public.attendance_day($1::date)`, [today]);
check(list[0].has_phone && list[0].guardian_name === 'Ayşe Yılmaz' && list[0].guardian_phone === '+905321234567',
  'veli telefonu kaydedildi', list[0]);
res = (await one(`select public.send_absence_sms($1::date, $2) r`, [today, [A.student]])).r;
check(res.queued === 1, 'SMS sıraya yazıldı', res);
res = (await one(`select public.send_absence_sms($1::date, $2) r`, [today, [A.student]])).r;
check(res.queued === 0 && res.skipped === 1, 'aynı gün ikinci SMS yok', res);
await expectError('koç başka öğrenci için SMS gönderemez', () =>
  db.query(`select public.send_absence_sms($1::date, $2)`, [today, [other]]), 'ATTENDANCE_NOT_MANAGER');
check((await rows(`select id from public.sms_outbox`)).length === 0, 'koç SMS kuyruğunu görmez');

await asUser(A.admin);
res = (await one(`select public.send_absence_sms($1::date, $2) r`, [today, [other]])).r;
check(res.skipped === 1, 'geç gelen için SMS gitmez', res);
const sms = await one(`select * from public.sms_outbox where attendance_id is not null`);
check(sms && sms.phone === '+905321234567'
  && sms.body === `Sayın Ayşe Yılmaz, Bal Akademi: öğrenciniz Bal Akademi Öğrenci ${today.split('-').reverse().join('.')} tarihinde kuruma gelmedi. Bilgilerinize.`,
  'SMS metni (müdür kuyruğu görür)', sms?.body);

console.log('Finanstaki veli telefonu yedek');
await db.query(`insert into public.finance_fees (student_id, title, total, payer_name, payer_phone)
  values ($1, 'Kurs', 1000, 'Mehmet Bey', '+905551112233')`, [other]);
await db.query(`select public.save_attendance($1::date, $2)`, [today, { [other]: 'absent' }]);
await asUser(coach2);
list = await rows(`select * from public.attendance_day($1::date)`, [today]);
check(list.length === 1 && list[0].has_phone && list[0].guardian_phone === null,
  'koç finans telefonunu görmez ama "telefon var" bilir', list);
res = (await one(`select public.send_absence_sms($1::date, $2) r`, [today, [other]])).r;
check(res.queued === 1, 'finans telefonuyla SMS', res);
await asSuper();
check((await one(`select phone from public.sms_outbox where body like '%Mehmet Bey%'`))?.phone === '+905551112233',
  'finanstaki numaraya gider');

console.log('Yalıtım');
for (const [who, n] of [[A.student, 'öğrenci'], [A.parent, 'veli'], [B.admin, 'öteki müdür'], [B.coach, 'öteki koç']]) {
  await asUser(who);
  check((await rows(`select id from public.attendance`)).length === 0, `${n} yoklamayı görmez`);
  check((await rows(`select student_id from public.student_guardian_phones`)).length === 0, `${n} veli telefonunu görmez`);
  check((await rows(`select * from public.attendance_day($1::date)`, [today]))
    .every((r) => r.student_id !== A.student), `${n} listede A öğrencisini görmez`);
  await expectError(`${n} A öğrencisini işaretleyemez`, () =>
    db.query(`select public.save_attendance($1::date, $2)`, [today, { [A.student]: 'present' }]), 'ATTENDANCE_NOT_MANAGER');
}
await asAnon();
await expectError('anonim çağıramaz', () => db.query(`select * from public.attendance_day(current_date)`), 'permission');

console.log('Saklama');
await asSuper();
await db.query(`update public.attendance set day = day - 400 where student_id = $1`, [A.student]);
check((await one(`select public.purge_old_attendance() n`)).n === 1, '1 yıldan eski yoklama silinir');

console.log('Geri alma ve yeniden uygulama');
const name = '20261105120000_attendance';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.attendance') t`)).t === null, 'yoklama tablosu kaldırıldı');
check((await one(`select to_regclass('public.sms_outbox') t`)).t !== null, 'SMS kuyruğu duruyor');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select to_regclass('public.attendance') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
