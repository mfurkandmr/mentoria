// Kurum lisansı bitince öğrenci, koç ve veli veriye erişemez; müdür panelini
// görür; lisans uzayınca erişim döner; geri alma.
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
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  return { admin, coach, org, code: (await one(`select public.create_invite('student', null, 10) c`)).c };
}

const A = await school('Bal Akademi', 'ADMINLA1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
await asUser(ahmet);
const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, 'Ahmet Veli');
const B = await school('Yıldız', 'ADMINLA2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

await asSuper();
await db.query(`insert into public.exams (student_id, exam_type, name, taken_on) values ($1, 'TYT', 'D1', current_date), ($2, 'TYT', 'D1', current_date)`, [ahmet, zeynep]);
await asUser(A.coach);
await db.query(`insert into public.plan_items (student_id, day, subject_code) values ($1, current_date, 'TYT_MAT')`, [ahmet]);

const exams = async (who, student = ahmet) => { await asUser(who); return (await one(`select count(*)::int c from public.exams where student_id = $1`, [student])).c; };
const plans = async (who) => { await asUser(who); return (await one(`select count(*)::int c from public.plan_items where student_id = $1`, [ahmet])).c; };
const active = async (who) => { await asUser(who); return (await one(`select public.my_license_active() a`)).a; };
const setLicense = async (org, sql) => { await asSuper(); await db.query(`update public.organizations set license_expires_at = ${sql} where id = $1`, [org]); };

console.log('Lisans geçerliyken');
check(await exams(ahmet) === 1 && await exams(A.coach) === 1 && await exams(parent) === 1, 'öğrenci, koç, veli denemeyi görür');
check(await active(ahmet) === true, 'my_license_active true');
await setLicense(A.org, `now() + interval '30 days'`);
check(await exams(ahmet) === 1 && await active(A.coach) === true, 'ileri tarihli lisansta erişim sürer');

console.log('Lisans bitince');
await setLicense(A.org, `now() - interval '1 minute'`);
check(await exams(ahmet) === 0, 'öğrenci kendi denemesini göremez');
check(await plans(ahmet) === 0, 'öğrenci planını göremez');
check(await exams(A.coach) === 0, 'koç öğrencinin denemesini göremez');
check(await exams(parent) === 0, 'veli göremez');
check(await active(ahmet) === false && await active(A.coach) === false && await active(parent) === false, 'my_license_active false');
await asUser(ahmet);
check((await one(`select count(*)::int c from public.profiles where id = $1`, [ahmet])).c === 1, 'kendi profilini okur (uygulama mesaj gösterebilsin)');
await expectError('öğrenci veri yazamaz', () => db.query(`insert into public.plan_items (student_id, day, subject_code) values ($1, current_date, 'TYT_MAT')`, [ahmet]));
await asUser(A.coach);
await expectError('koç yeni öğrenci daveti üretemez', () => db.query(`select public.create_invite('student', null, 10)`), 'LICENSE_EXPIRED');
await asUser(ahmet);
await expectError('öğrenci veli daveti üretemez', () => db.query(`select public.create_invite('parent')`), 'LICENSE_EXPIRED');
await asUser(A.admin);
await db.query(`select public.create_invite('coach')`);
ok('müdür davet üretebilir');
check(await active(A.admin) === true, 'müdür için true');
check(await exams(A.admin) === 1, 'müdür panelini ve verileri görmeye devam eder');
check(await exams(zeynep, zeynep) === 1 && await exams(B.coach, zeynep) === 1, 'başka kurum etkilenmez');

console.log('Lisans uzatılınca');
await setLicense(A.org, `now() + interval '1 year'`);
check(await exams(ahmet) === 1 && await exams(A.coach) === 1 && await exams(parent) === 1, 'erişim kendiliğinden döner');
await setLicense(A.org, 'null');
check(await exams(ahmet) === 1, 'süresiz lisans: erişim var');

console.log('Geri alma ve yeniden uygulama');
const name = '20261031110000_license_access';
await setLicense(A.org, `now() - interval '1 minute'`);
await db.exec(read(rbDir, `${name}.down.sql`));
check(await exams(ahmet) === 1, 'geri alınınca eski davranış (erişim sürer)');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
check(await exams(ahmet) === 0, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
