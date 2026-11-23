// Güvenlik regresyon testi (NOTLAR §107). Yeni bir tablo / işlev eklenince şunları otomatik denetler:
//  1. public'teki her tabloda RLS açık.
//  2. anon yalnızca izinli tablo ve işlevlere erişir (yeni bir şey eklenirse test kırılır;
//     gerçekten anonim olması gerekiyorsa aşağıdaki izin listesine bilerek eklenir).
//  3. İki kurumlu kurulumda B kurumunun koç / öğrenci / müdürü A kurumunun verisini
//     (çok sayıda tablo) göremez ve yazamaz.
//  4. Hassas sütunlar (rol, kurum, kredi) doğrudan güncellenemez; katalog tablolarına yazılamaz.
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';

const root = process.argv[2] ?? '../..';
const migDir = `${root}/supabase/migrations`;
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

console.log('RLS ve anon yüzeyi');
const noRls = (await rows(`select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity order by 1`)).map((r) => r.relname);
check(noRls.length === 0, 'public tablolarının hepsinde RLS açık', noRls);

// anon'a tablo yetkisi: yalnızca bunlar (canlıyla aynı; yenisi bilerek eklenmeli).
const ANON_TABLES = new Set(['app_config']);
const anonTables = (await rows(`select table_name from information_schema.role_table_grants
  where table_schema = 'public' and grantee = 'anon' group by table_name order by 1`)).map((r) => r.table_name);
const extraTables = anonTables.filter((t) => !ANON_TABLES.has(t));
check(extraTables.length === 0, 'anon yalnızca izinli tablolara erişir', extraTables);

// anon'ın çalıştırabildiği işlevler: yardımcılar, tetikleyiciler ve bilerek anonim olanlar.
const ANON_FUNCS = new Set([
  'check_invite', 'match_student_number', 'report_client_error', 'tenant_branding', // anonim kayıt / hata / marka
  'clamp_profile_name', 'current_term', 'daily_question_id', 'guard_task_update', 'meeting_occurs_on',
  'norm_booklet', 'norm_key', 'practice_daily_limit', 'slugify', 'stamp_item_done', 'term_of', 'touch_updated_at',
]);
const anonFuncs = (await rows(`select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f' and has_function_privilege('anon', p.oid, 'execute') order by 1`)).map((r) => r.proname);
const extraFuncs = [...new Set(anonFuncs)].filter((f) => !ANON_FUNCS.has(f));
check(extraFuncs.length === 0, 'anon yalnızca izinli işlevleri çalıştırır', extraFuncs);

// SECURITY DEFINER işlevler anon'a açılamaz (izin listesindekiler hariç).
const defAnon = (await rows(`select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute') order by 1`))
  .map((r) => r.proname).filter((f) => !['check_invite', 'match_student_number', 'report_client_error', 'tenant_branding'].includes(f));
check(defAnon.length === 0, 'anon hiçbir SECURITY DEFINER işlevi (izinliler hariç) çalıştıramaz', defAnon);

console.log('İki kurumlu kurulum');
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
  const student = await signUp(await invite(coach, 'student'), `${name} Öğrenci`);
  await asSuper();
  return { org, admin, coach, student };
}
const A = await school('Bal Akademi', 'ADMINSG1');
const B = await school('Arı Kurs', 'ADMINSG2');

// A öğrencisine ait örnek veriler.
await asSuper();
const subj = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
const topic = (await one(`select id from public.topics where subject_id = $1 limit 1`, [subj])).id;
await db.query(`insert into public.goals (student_id, daily_questions) values ($1, 50)`, [A.student]);
await db.query(`insert into public.question_logs (student_id, subject_id, correct, wrong, blank, logged_on) values ($1, $2, 5, 2, 1, current_date)`, [A.student, subj]);
await db.query(`insert into public.topic_progress (student_id, topic_id, status) values ($1, $2, 'done')`, [A.student, topic]);
await db.query(`insert into public.coach_notes (student_id, coach_id, body) values ($1, $2, 'özel not')`, [A.student, A.coach]);
await db.query(`insert into public.plan_items (student_id, day, subject_code) values ($1, current_date, 'TYT_MAT')`, [A.student]);
await asUser(A.coach);
await db.query(`select public.send_assignment($1, 'Ödev', $2::jsonb)`, [A.student, JSON.stringify([{ subject_code: 'TYT_MAT', topic_id: topic }])]);
await asSuper();

const TABLES = [
  ['profiles', 'id'], ['goals', 'student_id'], ['question_logs', 'student_id'], ['topic_progress', 'student_id'],
  ['coach_notes', 'student_id'], ['plan_items', 'student_id'], ['assignments', 'student_id'], ['notifications', 'user_id'],
  ['exams', 'student_id'], ['tasks', 'student_id'], ['student_books', 'student_id'], ['study_sessions', 'student_id'],
  ['mistake_cards', 'student_id'], ['guidance_logs', 'student_id'], ['coach_students', 'student_id'],
];
const aVisible = async (who) => {
  const out = [];
  for (const [t, col] of TABLES) {
    await asUser(who);
    const n = (await one(`select count(*)::int c from public.${t} where ${col} = $1`, [A.student])).c;
    await asSuper();
    if (n > 0) out.push(`${t}:${n}`);
  }
  return out;
};
// Kontrol: A'nın kendi koçu görür (test gerçekten veri içeriyor).
const own = await aVisible(A.coach);
check(own.length >= 5, 'kontrol: A koçu kendi öğrencisinin verisini görür', own);
for (const [who, id] of [['B koçu', B.coach], ['B öğrencisi', B.student], ['B müdürü', B.admin]]) {
  const seen = await aVisible(id);
  check(seen.length === 0, `${who} A öğrencisinin verisini hiçbir tabloda göremez`, seen);
}

console.log('Yazma ve RPC');
await asUser(B.coach);
for (const [n, sql, p] of [
  ['B koçu A öğrencisinin müfredatını değiştiremez', `select public.set_curriculum($1, 'maarif')`, [A.student]],
  ['B koçu A öğrencisine ödev gönderemez', `select public.send_assignment($1, 'x', '[]'::jsonb)`, [A.student]],
]) {
  let err = null;
  try { await db.query(sql, p); } catch (e) { err = e.message; }
  check(err !== null, n, err);
}
for (const [n, sql] of [
  ['B koçu A öğrencisinin profilini güncelleyemez', `update public.profiles set full_name = 'x' where id = '${A.student}'`],
  ['B koçu A öğrencisinin hedefini silemez', `delete from public.goals where student_id = '${A.student}'`],
  ['B koçu A öğrencisinin konu ilerlemesini değiştiremez', `update public.topic_progress set status = 'review' where student_id = '${A.student}'`],
]) {
  const r = await db.query(sql);
  check((r.affectedRows ?? 0) === 0, n, r.affectedRows);
}
await asSuper();
check((await one(`select count(*)::int c from public.goals where student_id = $1`, [A.student])).c === 1, 'A verisi yazma denemelerinden sonra aynı');

console.log('Hassas sütunlar ve katalog tabloları');
await asUser(A.student);
for (const [n, sql] of [
  ['öğrenci kendi rolünü yükseltemez', `update public.profiles set role = 'admin' where id = '${A.student}'`],
  ['öğrenci kendi kurumunu değiştiremez', `update public.profiles set org_id = '${B.org}' where id = '${A.student}'`],
  ['öğrenci kurum kredisini değiştiremez', `update public.organizations set credit_balance = 999999 where id = '${A.org}'`],
  ['öğrenci konu kataloğuna ekleyemez', `insert into public.topics (subject_id, name) values (${subj}, 'hack')`],
  ['öğrenci ders kataloğunu silemez', `delete from public.subjects`],
]) {
  let err = null, count = null;
  try { const r = await db.query(sql); count = r.affectedRows ?? 0; } catch (e) { err = e.message; }
  check(err !== null || count === 0, n, { err, count });
}
await asSuper();
check((await one(`select role::text r from public.profiles where id = $1`, [A.student])).r === 'student', 'rol hâlâ öğrenci');
check((await one(`select org_id from public.profiles where id = $1`, [A.student])).org_id === A.org, 'kurum hâlâ A');

if (failures) { console.log(`\n${failures} test BAŞARISIZ`); process.exit(1); }
console.log('\nTüm güvenlik regresyon testleri geçti');
