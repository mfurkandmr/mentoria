// İnceleme düzeltmeleri (20261114100000_review_fixes): geçmiş tarihli talep
// onaylanmaz, pasif kurumda öğretmen göremez/karar veremez, öğretmen daveti
// lisans süresini denetler, soru çözümü talepleri saklama süresiyle silinir, geri alma.
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


await asUser(A.admin);
const sess = await one(`insert into public.tutoring_sessions (teacher_id, kind, day, start_time, end_time, capacity)
  values ($1, 'question_solving', $2, '15:00', '16:00', 3) returning *`, [A.teacher, DOW]);
await asUser(A.s1);
const req = (await one(`select public.request_tutoring_session($1, $2, 'limit') id`, [sess.id, D])).id;
await asUser(A.s2);
const req2 = (await one(`select public.request_tutoring_session($1, $2, null) id`, [sess.id, D])).id;
await asUser(A.s3);
const req3 = (await one(`select public.request_tutoring_session($1, $2, null) id`, [sess.id, D])).id;

console.log('Geçmiş tarih / pasif oturum');
await asSuper();
await db.query(`update public.tutoring_requests set on_date = public.tr_now()::date - 1 where id = $1`, [req]);
await asUser(A.teacherUser);
await expectError('geçmiş tarihli talep onaylanamaz', () => db.query(`select public.decide_tutoring_request($1, true)`, [req]), 'TUTOR_BAD_DATE');
await db.query(`select public.decide_tutoring_request($1, false, 'geçti')`, [req]);
ok('geçmiş tarihli talep yine de reddedilebilir');
await asSuper();
await db.query(`update public.tutoring_sessions set active = false where id = $1`, [sess.id]);
await asUser(A.teacherUser);
check((await rows(`select * from public.my_tutoring_sessions()`)).length === 0, 'pasif oturum öğretmen listesinde yok');
await expectError('pasif oturumdaki talep onaylanamaz', () => db.query(`select public.decide_tutoring_request($1, true)`, [req2]), 'TUTOR_BAD_DATE');
await asSuper();
await db.query(`update public.tutoring_sessions set active = true where id = $1`, [sess.id]);

console.log('Pasif kurum');
await asUser(A.teacherUser);
check((await rows(`select * from public.teacher_tutoring_requests(public.tr_now()::date, 14)`)).length >= 1, 'aktif kurumda öğretmen talepleri görür');
await asSuper();
await db.query(`update public.tenants set is_active = false where id = (select tenant_id from public.organizations where id = $1)`, [A.org]);
await asUser(A.teacherUser);
check((await rows(`select * from public.teacher_tutoring_requests(public.tr_now()::date, 14)`)).length === 0, 'pasif kurumda talepler boş');
check((await rows(`select * from public.my_tutoring_sessions()`)).length === 0, 'pasif kurumda oturumlar boş');
await expectError('pasif kurumda karar verilemez', () => db.query(`select public.decide_tutoring_request($1, true)`, [req2]), 'NOT_ALLOWED');
await asSuper();
await db.query(`update public.tenants set is_active = true where id = (select tenant_id from public.organizations where id = $1)`, [A.org]);
await asUser(A.teacherUser);
await db.query(`select public.decide_tutoring_request($1, true)`, [req2]);
ok('kurum yeniden aktifken onay çalışır');

console.log('Öğretmen daveti ve lisans');
const inv = await invite(A.admin, 'teacher');
await asSuper();
await db.query(`update public.organizations set license_expires_at = now() - interval '1 day' where id = $1`, [A.org]);
await asUser(A.admin);
await expectError('lisansı bitmiş kurum öğretmen daveti oluşturamaz', () => db.query(`select public.create_invite('teacher')`), 'LICENSE_EXPIRED');
await expectError('lisansı bitmiş kurumda öğretmen kaydı olmaz', () => signUp(inv, 'Geç Öğretmen', { teacher_branches: ['Fizik'] }));
await asSuper();
await db.query(`update public.organizations set license_expires_at = null where id = $1`, [A.org]);
await signUp(await invite(A.admin, 'teacher'), 'Yeni Öğretmen', { teacher_branches: ['Fizik'] });
ok('lisans geçerliyken öğretmen kaydı çalışır');

console.log('Saklama süresi');
await asSuper();
await db.query(`update public.tutoring_requests set on_date = public.tr_now()::date - 400 where id = $1`, [req3]);
const rj = Number((await one(`select public.purge_old_tutoring_requests() n`)).n);
check(rj >= 1, 'eski talepler silindi', rj);
check(!(await one(`select 1 x from public.tutoring_requests where id = $1`, [req3])), 'eski talep yok');
check(!!(await one(`select 1 x from public.tutoring_requests where id = $1`, [req2])), 'yeni talep duruyor');

console.log('Geri alma');
const name = '20261114100000_review_fixes';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select count(*) n from information_schema.columns where table_name = 'retention_settings' and column_name = 'tutoring_keep'`)).n == 0, 'geri alındı');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select count(*) n from information_schema.columns where table_name = 'retention_settings' and column_name = 'tutoring_keep'`)).n == 1, 'yeniden uygulandı');

console.log('claim_sms kaldırıldı');
check((await one(`select to_regprocedure('public.claim_sms(int)') f`)).f === null, 'claim_sms yok');
await db.exec(read(rbDir, '20261114110000_drop_claim_sms.down.sql'));
check((await one(`select to_regprocedure('public.claim_sms(int)') f`)).f !== null, 'geri alınca claim_sms döner');
await db.exec(read(migDir, '20261114110000_drop_claim_sms.sql'));
check((await one(`select to_regprocedure('public.claim_sms(int)') f`)).f === null, 'yeniden uygulandı');

console.log(failures ? `${failures} BASARISIZ` : 'Hepsi gecti');
process.exit(failures ? 1 : 0);
