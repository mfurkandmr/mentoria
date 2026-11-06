// Velilere serbest metinli toplu SMS (20261105150000_bulk_sms).
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

const A = await school('Bal Akademi', 'ADMINBS1');
const B = await school('Arı Kurs', 'ADMINBS2');
await asUser(A.coach);
const s2 = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, 'Kardeş Öğrenci');
await asUser(A.coach);
const s3 = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, 'Telefonsuz Öğrenci');

console.log('Hazırlık: sınıf ve veli telefonları');
await asUser(A.admin);
const cls = await one(`insert into public.classrooms (name) values ('Sayısal-1') returning id`);
await db.query(`select public.assign_students_to_class($1, $2)`, [[A.student], cls.id]);
await db.query(`select public.set_guardian_phone($1, 'Ayşe', '+905321112233')`, [A.student]);
// Kardeş: aynı veli numarası.
await db.query(`select public.set_guardian_phone($1, 'Ayşe', '+905321112233')`, [s2]);
await db.query(`insert into public.finance_fees (student_id, title, total, payer_phone) values ($1, 'Kurs', 100, '+905559998877')`, [s3]);
await db.query(`delete from public.finance_fees where student_id = $1`, [s3]);

console.log('Önizleme');
let r = (await one(`select public.send_bulk_sms('', 'all', null, null, true) r`)).r;
check(r.students === 3 && r.recipients === 1 && r.no_phone === 1, 'tümü: kardeşler tek numara, telefonsuz sayılır', r);
r = (await one(`select public.send_bulk_sms('', 'classes', $1, null, true) r`, [[cls.id]])).r;
check(r.students === 1 && r.recipients === 1, 'sınıf seçimi', r);
r = (await one(`select public.send_bulk_sms('', 'students', null, $1, true) r`, [[s3]])).r;
check(r.students === 1 && r.recipients === 0 && r.no_phone === 1, 'öğrenci seçimi (telefonsuz)', r);
await expectError('alıcısız gönderim yok', () =>
  db.query(`select public.send_bulk_sms('Merhaba', 'students', null, $1)`, [[s3]]), 'NO_RECIPIENTS');
await expectError('boş metin', () => db.query(`select public.send_bulk_sms('  ', 'all')`), 'BAD_BODY');
await expectError('çok uzun metin', () => db.query(`select public.send_bulk_sms($1, 'all')`, ['x'.repeat(601)]), 'BAD_BODY');
await expectError('başka kurumun öğrencisi sayılmaz', async () => {
  const x = (await one(`select public.send_bulk_sms('', 'students', null, $1, true) r`, [[B.student]])).r;
  if (x.students !== 0) throw new Error('sayıldı');
  throw new Error('OK_ZERO');
}, 'OK_ZERO');

console.log('Gönderim');
r = (await one(`select public.send_bulk_sms('29 Ekim nedeniyle kurumumuz kapalıdır.', 'all') r`)).r;
check(r.recipients === 1 && r.id, 'gönderildi', r);
const sms = await rows(`select phone, body from public.sms_outbox where broadcast_id = $1`, [r.id]);
check(sms.length === 1 && sms[0].phone === '+905321112233'
  && sms[0].body === 'Bal Akademi: 29 Ekim nedeniyle kurumumuz kapalıdır.', 'metin kurum adıyla sırada', sms);
await expectError('10 dakika içinde ikinci gönderim yok', () =>
  db.query(`select public.send_bulk_sms('Tekrar', 'all')`), 'SMS_TOO_SOON');
const hist = await rows(`select * from public.my_sms_broadcasts()`);
check(hist.length === 1 && hist[0].queued === 1 && hist[0].recipients === 1 && hist[0].sender === 'Bal Akademi Müdür',
  'geçmiş: durum sayıları', hist);
await expectError('tabloya doğrudan yazılamaz', () =>
  db.query(`insert into public.sms_broadcasts (org_id, tenant_id, body, audience) values ($1, gen_random_uuid(), 'x', 'all')`, [A.org]),
  'permission');

console.log('Yetki');
for (const [who, n] of [[A.coach, 'koç'], [A.student, 'öğrenci'], [A.parent, 'veli']]) {
  await asUser(who);
  await expectError(`${n} gönderemez`, () => db.query(`select public.send_bulk_sms('x', 'all')`), 'NOT_ALLOWED');
  check((await rows(`select * from public.my_sms_broadcasts()`)).length === 0, `${n} geçmişi görmez`);
}
await asUser(B.admin);
check((await rows(`select * from public.my_sms_broadcasts()`)).length === 0, 'öteki müdür geçmişi görmez');
check((await rows(`select id from public.sms_broadcasts`)).length === 0, 'öteki müdür tabloyu görmez');
await asAnon();
await expectError('anonim çağıramaz', () => db.query(`select public.send_bulk_sms('x', 'all')`), 'permission');

console.log('Geri alma ve yeniden uygulama');
await asSuper();
const name = '20261105150000_bulk_sms';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.sms_broadcasts') t`)).t === null, 'tablo kaldırıldı');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select to_regclass('public.sms_broadcasts') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
