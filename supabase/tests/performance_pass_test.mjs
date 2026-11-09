// Performans geçişi (20261109120000_performance_pass): index'ler, student_summaries'in DEFINER'a geçerken
// görünürlüğü koruması, tarih/hafta sınırlarının aynı kalması, geri alma.

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
async function signUp(code, name) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true, privacy_version: '1.0' })])).id;
}
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(admin);
  const coach2 = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} İkinci Koç`);
  await asUser(coach);
  const sCode = (await one(`select public.create_invite('student', null, 5) c`)).c;
  const s1 = await signUp(sCode, `${name} Ali`);
  const s2 = await signUp(sCode, `${name} Banu`);
  return { org, admin, coach, coach2, s1, s2 };
}
const A = await school('Ayşe Kurs', 'PERF-A');
const B = await school('Bora Kurs', 'PERF-B');
const summaries = () => rows(`select * from public.student_summaries()`);

console.log('Index\'ler');
await asSuper();
const idx = (await rows(`select indexname from pg_indexes where schemaname = 'public'`)).map((r) => r.indexname);
for (const n of ['exams_batch_id_source_idx', 'exams_student_type_recent_idx', 'notifications_kind_ref_id_idx',
  'rooms_tenant_id_idx', 'schedule_entries_tenant_id_idx', 'org_exam_plans_created_by_idx']) {
  check(idx.includes(n), `${n} var`);
}
check(!idx.includes('exam_answers_subject_id_idx') && !idx.includes('exams_created_by_idx'), 'kapsanan iki index kalktı');
const fks = await rows(`
  select c.conrelid::regclass::text t, c.conname
    from pg_constraint c
   where c.contype = 'f' and c.connamespace = 'public'::regnamespace
     and not exists (
       select 1 from pg_index i
        where i.indrelid = c.conrelid
          and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] @> c.conkey)`);
check(fks.length === 0, 'index\'siz yabancı anahtar kalmadı', fks);

console.log('student_summaries görünürlüğü (DEFINER)');
check((await one(`select prosecdef d from pg_proc where proname = 'student_summaries'`)).d === true, 'artık DEFINER');
await db.query(`insert into public.coach_students (coach_id, student_id, org_id) values ($1, $2, $3)`, [A.coach2, A.s1, A.org]);
await asUser(A.coach);
let r = await summaries();
check(r.length === 2 && r.every((x) => x.coach_id === A.coach), 'iki koçlu öğrenci koçta bir kez, kendi koç adıyla', r);
await asUser(A.coach2);
r = await summaries();
check(r.length === 1 && r[0].student_id === A.s1 && r[0].coach_id === A.coach2, 'ikinci koç yalnızca kendi öğrencisini görür', r);
await asUser(A.admin);
check((await summaries()).length === 3, 'müdür iki bağı da görür (iki öğrenci, üç satır)');
await asUser(B.admin);
check((await summaries()).every((x) => ![A.s1, A.s2].includes(x.student_id)), 'öteki kurum görmez');
await asUser(A.s1);
check((await summaries()).length === 0, 'öğrenci boş');

await asSuper();
await db.query(`update public.organizations set license_expires_at = now() - interval '1 day' where id = $1`, [A.org]);
await asUser(A.coach);
check((await summaries()).length === 0, 'lisansı biten kurumun koçu görmez');
await asSuper();
await db.query(`update public.organizations set license_expires_at = null where id = $1`, [A.org]);
const tenant = (await one(`select tenant_id t from public.profiles where id = $1`, [A.admin])).t;
await db.query(`update public.tenants set is_active = false where id = $1`, [tenant]);
await asUser(A.admin);
check((await summaries()).length === 0, 'pasif dershanenin müdürü görmez');
await asSuper();
await db.query(`update public.tenants set is_active = true where id = $1`, [tenant]);

console.log('Haftalık özet: İstanbul günü sınırı');
await db.query(`
  insert into public.study_sessions (student_id, started_at, duration_sec) values
    ($1, (((now() at time zone 'Europe/Istanbul')::date - 6)::timestamp at time zone 'Europe/Istanbul'), 600),
    ($1, (((now() at time zone 'Europe/Istanbul')::date - 6)::timestamp at time zone 'Europe/Istanbul') - interval '1 second', 1200)`, [A.s2]);
const wk = (await one(`select public.weekly_summary_data($1) s`, [A.s2])).s;
check(wk.minutes === 10 && wk.days === 1, 'ilk günün gece yarısı dahil, bir saniye öncesi hariç', wk);

console.log('Haftalık eğilim: hafta sınırı');
const subject = (await one(`select id from public.subjects limit 1`)).id;
await db.query(`
  insert into public.question_logs (student_id, subject_id, correct, wrong, blank, logged_on) values
    ($1, $2, 10, 0, 0, current_date - 6),
    ($1, $2, 20, 0, 0, current_date - 7),
    ($1, $2, 40, 0, 0, current_date - 14)`, [A.s1, subject]);
await asUser(A.coach);
const w = (await one(`select public.activity_weeks(2) w`)).w;
check(w.length === 2 && w[1].questions === 10 && w[0].questions === 20, 'günler doğru haftada, aralık dışı sayılmaz', w);
// Banu'nun İstanbul gece yarısındaki kaydı UTC'de bir önceki güne düşer (fonksiyon oturum saatiyle sayar).
check(w[1].active === 1 && w[0].active === 2, 'aktif: soru ya da çalışma kaydı, tekil öğrenci', w);
const wide = (await one(`select public.activity_weeks(4) w`)).w;

console.log('Geri alma');
await asSuper();
await db.exec(read(rbDir, '20261109120000_performance_pass.down.sql'));
check((await one(`select prosecdef d from pg_proc where proname = 'student_summaries'`)).d === false, 'student_summaries eski haline döndü');
const after = (await rows(`select indexname from pg_indexes where schemaname = 'public'`)).map((r) => r.indexname);
check(after.includes('exams_created_by_idx') && !after.includes('exams_batch_id_source_idx'), 'index\'ler eski haline döndü');
await asUser(A.coach);
const oldWide = (await one(`select public.activity_weeks(4) w`)).w;
check(JSON.stringify(oldWide) === JSON.stringify(wide), 'eski ve yeni activity_weeks birebir aynı', { oldWide, wide });
await asSuper();
await db.exec(read(migDir, '20261109120000_performance_pass.sql'));
check((await one(`select prosecdef d from pg_proc where proname = 'student_summaries'`)).d === true, 'yeniden uygulanır');

await db.close();
if (failures) { console.log(`${failures} test başarısız`); process.exit(1); }
console.log('Performans testleri geçti');
