// Güvenlik denetimi düzeltmeleri (20261120100000_security_fixes, 20261120110000_duel_consent):
// profil adı 100 karakterle sınırlı, soru çözümü talebi 24 saatte 15 ile sınırlı
// (iptal edilenler sayılır), düello rakip listesi ve davet rıza kuralına bağlı, geri alma.
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
const guardianInvite = async (as) => {
  await asUser(as);
  return (await one(`select public.create_invite('student', null, 1, true) c`)).c;
};
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  const admin = await signUp(code, `${name} Müdür`);
  const coach = await signUp(await invite(admin, 'coach'), `${name} Koç`);
  const s1 = await signUp(await invite(coach, 'student'), `${name} Ali`);
  const s2 = await signUp(await invite(coach, 'student'), `${name} Ayşe`);
  const s3 = await signUp(await invite(coach, 'student'), `${name} Can`);
  const teacherUser = await signUp(await invite(admin, 'teacher'), `${name} Selin`, { teacher_branches: ['Matematik'] });
  await asSuper();
  const teacher = (await one(`select id from public.teachers where profile_id = $1`, [teacherUser])).id;
  return { org, admin, coach, s1, s2, s3, teacherUser, teacher };
}

const A = await school('Bal Akademi', 'ADMINSS1');

console.log('Profil adı uzunluğu');
const longId = await signUp(await invite(A.coach, 'student'), 'A'.repeat(500000));
await asSuper();
check((await one(`select char_length(full_name) n from public.profiles where id = $1`, [longId])).n === 100,
  'kayıtta 500 KB ad 100 karaktere kısalır');
await asUser(A.s1);
await db.query(`update public.profiles set full_name = repeat('B', 300) where id = $1`, [A.s1]);
await asSuper();
check((await one(`select char_length(full_name) n from public.profiles where id = $1`, [A.s1])).n === 100,
  'profil güncellemesinde de 100 karakter');
await asUser(A.s1);
await db.query(`update public.profiles set full_name = '  Ali Veli  ' where id = $1`, [A.s1]);
await asSuper();
check((await one(`select full_name from public.profiles where id = $1`, [A.s1])).full_name === 'Ali Veli',
  'normal ad olduğu gibi (baş/son boşluk temizlenir)');

console.log('Soru çözümü talebi hız sınırı');
const target = (await one(`select (public.tr_now()::date + 2) d, extract(isodow from public.tr_now()::date + 2)::int dow`));
const D = target.d instanceof Date ? target.d.toISOString().slice(0, 10) : String(target.d);
await asUser(A.admin);
const sess = await one(`insert into public.tutoring_sessions (teacher_id, kind, day, start_time, end_time, capacity)
  values ($1, 'question_solving', $2, '15:00', '16:00', 3) returning *`, [A.teacher, target.dow]);
await asUser(A.s2);
let made = 0;
let blocked = null;
for (let i = 0; i < 20; i++) {
  try {
    const id = (await one(`select public.request_tutoring_session($1, $2, $3) id`, [sess.id, D, `deneme ${i}`])).id;
    made++;
    await db.query(`select public.cancel_tutoring_request($1)`, [id]);
  } catch (e) { blocked = e.message; break; }
}
check(made === 15 && String(blocked).includes('TUTOR_RATE_LIMIT'), '15 talepten sonra TUTOR_RATE_LIMIT', { made, blocked });
await asSuper();
check((await one(`select count(*)::int n from public.notifications where user_id = $1 and kind = 'tutoring_request'`,
  [A.teacherUser])).n === 15, 'öğretmene en çok 15 bildirim gitti');
await asUser(A.s3);
const first = (await one(`select public.request_tutoring_session($1, $2, 'normal') id`, [sess.id, D])).id;
check(!!first, 'başka öğrencinin hakkı etkilenmez');
await asSuper();
await db.query(`update public.tutoring_requests set created_at = now() - interval '25 hours' where student_id = $1`, [A.s2]);
await asUser(A.s2);
await db.query(`select public.request_tutoring_session($1, $2, 'sonra') id`, [sess.id, D]);
ok('24 saat geçince yeniden talep açılabilir');

console.log('Düello rıza kuralı');
await asSuper();
const consentedCode = await guardianInvite(A.coach);
const consented = await signUp(consentedCode, 'Rıza Veren', { consents: { ranking: true } });
await asSuper();
check((await one(`select public.ranking_visible($1) v`, [consented])).v === true, 'kurulum: rıza veren öğrenci görünür');
check((await one(`select public.ranking_visible($1) v`, [A.s3])).v === false, 'kurulum: rıza vermeyen görünmez');
await asUser(A.s1);
const opp = await rows(`select student_id from public.duel_opponents()`);
check(opp.length === 1 && opp[0].student_id === consented, 'rakip listesinde yalnızca rıza verenler', opp);
await expectError('rıza vermeyen öğrenci davet edilemez', () =>
  db.query(`select public.create_duel($1, 'TYT_MAT')`, [A.s3]), 'DUEL_BAD_OPPONENT');
let inviteErr = null;
try { await db.query(`select public.create_duel($1, 'TYT_MAT')`, [consented]); } catch (e) { inviteErr = e.message; }
check(!inviteErr || !inviteErr.includes('DUEL_BAD_OPPONENT'), 'rıza veren öğrenci davet edilebilir (rakip hatası yok)', inviteErr);

console.log('Geri alma ve yeniden uygulama');
await asSuper();
await db.exec(read(rbDir, '20261120110000_duel_consent.down.sql'));
await asUser(A.s1);
check((await rows(`select student_id from public.duel_opponents()`)).length >= 3, 'düello geri alınınca herkes listelenir');
await asSuper();
await db.exec(read(migDir, '20261120110000_duel_consent.sql'));
await asUser(A.s1);
check((await rows(`select student_id from public.duel_opponents()`)).length === 1, 'düello yeniden uygulandı');
await asSuper();
await db.exec(read(rbDir, '20261120100000_security_fixes.down.sql'));
check((await one(`select count(*)::int n from pg_trigger where tgname = 'clamp_profile_name'`)).n === 0, 'ad tetikleyicisi kalktı');
await db.exec(read(migDir, '20261120100000_security_fixes.sql'));
check((await one(`select count(*)::int n from pg_trigger where tgname = 'clamp_profile_name'`)).n === 1, 'ad tetikleyicisi geri geldi');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
