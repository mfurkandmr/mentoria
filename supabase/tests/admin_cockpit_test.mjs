// Müdür kokpiti (20261106160000_admin_cockpit + 20261106170000_activity_weeks): son görülme, deneme takvimi, koç telefonu, koça bildirim, admin_cockpit(), activity_weeks().

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
  const s1 = await signUp(sCode, `${name} Ali`);
  const s2 = await signUp(sCode, `${name} Banu`);
  const s3 = await signUp(sCode, `${name} Cem`);
  return { org, admin, coach, s1, s2, s3 };
}

const A = await school('Bal Akademi', 'ADMINCK1');
const B = await school('Arı Kurs', 'ADMINCK2');
const cockpit = async () => (await one(`select public.admin_cockpit() c`)).c;

console.log('Yetki');
await asUser(A.coach);
await expectError('koç kokpiti çağıramaz', () => db.query(`select public.admin_cockpit()`), 'COCKPIT_NOT_ADMIN');
await expectError('koç deneme planlayamaz', () => db.query(`select public.add_exam_plan('TYT 1', 'TYT', current_date + 3)`), 'COCKPIT_NOT_ADMIN');
await asAnon();
await expectError('anonim çağıramaz', () => db.query(`select public.admin_cockpit()`), 'permission');

console.log('Son görülme');
await asUser(A.s1);
await db.query(`select public.touch_last_seen()`);
const seen1 = (await one(`select last_seen_at from public.profiles where id = $1`, [A.s1])).last_seen_at;
check(seen1 !== null, 'açılış son görülmeyi yazdı');
await db.query(`select public.touch_last_seen()`);
const seen2 = (await one(`select last_seen_at from public.profiles where id = $1`, [A.s1])).last_seen_at;
check(+seen1 === +seen2, 'bir saat dolmadan tekrar yazılmaz');

console.log('Etkinlik');
await asSuper();
// Hepsi 10 gün önce kayıt olmuş sayılsın; Banu 9 gündür görünmüyor, Cem hiç.
await db.query(`update public.profiles set created_at = now() - interval '10 days' where org_id = $1 and role = 'student'`, [A.org]);
await db.query(`update public.profiles set last_seen_at = now() - interval '9 days' where id = $1`, [A.s2]);
const mat = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
await asUser(A.s1);
await db.query(`insert into public.question_logs (student_id, subject_id, correct, wrong, blank, logged_on) values ($1, $2, 80, 15, 5, current_date)`, [A.s1, mat]);
await db.query(`insert into public.question_logs (student_id, subject_id, correct, logged_on) values ($1, $2, 40, current_date - 9)`, [A.s1, mat]);
await db.query(`insert into public.study_sessions (student_id, started_at, duration_sec) values ($1, now() - interval '1 day', 3600)`, [A.s1]);
await asUser(A.s2);
await db.query(`insert into public.question_logs (student_id, subject_id, correct, logged_on) values ($1, $2, 30, current_date - 10)`, [A.s2, mat]);
await asSuper();
await db.query(`update public.question_logs set created_at = now() - interval '10 days' where student_id = $1`, [A.s2]);

console.log('Denemeler');
const exam = async (sid, type, days, correct) => {
  await asSuper();
  const id = (await one(`insert into public.exams (student_id, exam_type, name, taken_on) values ($1, $2, 'D', current_date - $3::int) returning id`, [sid, type, days])).id;
  await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct) values ($1, $2, $3)`, [id, mat, correct]);
};
await exam(A.s1, 'TYT', 20, 30);
await exam(A.s1, 'TYT', 5, 25);   // 5 net düştü
await exam(A.s2, 'TYT', 20, 30);
await exam(A.s2, 'TYT', 5, 29);   // 1 net: eşiğin altında
await exam(A.s3, 'TYT', 90, 30);
await exam(A.s3, 'TYT', 60, 20);  // eski deneme: sayılmaz

console.log('Taksit');
await asUser(A.admin);
await db.query(`select public.create_fee($1, 'YKS', 10000, '[]', $2, null, 5, null, null)`,
  [A.s3, JSON.stringify([{ due_on: '2026-01-05', amount: 5000 }, { due_on: '2099-01-05', amount: 5000 }])]);

console.log('Görüşme');
await asUser(A.coach);
const monday = (await one(`select date_trunc('week', current_date)::date d`)).d;
const sch = (await one(`insert into public.meeting_schedules (coach_id, student_id, first_date, start_time) values ($1, $2, $3, '10:00') returning id`, [A.coach, A.s1, monday])).id;
await db.query(`select public.set_meeting_status($1, $2, 'held')`, [sch, monday]);

console.log('Kokpit');
await asUser(A.admin);
let c = await cockpit();
check(c.students === 3 && c.students_prev === 3, 'kayıtlı öğrenci ve geçen hafta', c);
check(c.active === 1 && c.active_prev === 2, 'bu hafta 1, geçen hafta 2 aktif', { a: c.active, p: c.active_prev });
check(c.questions === 100 && c.questions_prev === 70 && c.minutes === 60, 'soru ve süre toplamları', c);
const inactive = c.inactive.map((x) => x.full_name);
check(inactive.length === 2 && inactive[0].endsWith('Cem') && inactive[1].endsWith('Banu'),
  '7+ gün görünmeyenler: önce hiç görünmeyen', inactive);
check(c.net_drops.length === 1 && c.net_drops[0].student_id === A.s1 && Number(c.net_drops[0].last_net) === 25 && Number(c.net_drops[0].prev_net) === 30,
  'yalnızca 3+ net düşen ve son 45 günde denemesi olan', c.net_drops);
check(c.overdue.length === 1 && c.overdue[0].student_id === A.s3 && Number(c.overdue[0].amount) === 5000 && c.overdue[0].count === 1,
  'yalnızca vadesi geçen taksit', c.overdue);
check(c.coaches.length === 1 && c.coaches[0].students === 3 && c.coaches[0].active === 1 &&
  c.coaches[0].meetings_planned === 1 && c.coaches[0].meetings_held === 1 && c.coaches[0].phone === null,
  'koç: öğrenci, aktif, görüşme', c.coaches);
check(c.inactive[0].coach_name.endsWith('Koç'), 'satırda koçun adı var');

console.log('Haftalık eğilim (20261106170000_activity_weeks)');
const weeks = async () => (await one(`select public.activity_weeks(3) w`)).w;
let w = await weeks();
check(w.length === 3 && w[2].active === 1 && w[2].questions === 100 && w[2].students === 3,
  'bu hafta: 1 aktif, 100 soru, 3 kayıtlı (en yeni sonda)', w);
check(w[1].active === 2 && w[1].questions === 70, 'geçen hafta: 2 aktif, 70 soru', w[1]);
check(w[0].active === 0 && w[0].students === 0, 'üç hafta önce: henüz kayıt yok', w[0]);
await asUser(A.coach);
check((await weeks())[2].active === 1, 'koç kendi öğrencilerinin eğilimini görür');
await asUser(A.s1);
check((await weeks()).every((x) => x.students === 0 && x.active === 0), 'öğrenci veri görmez');
await asUser(B.admin);
check((await weeks())[2].students === 3 && (await weeks())[2].active === 0, 'öteki kurum yalnızca kendini görür');
await asUser(A.admin);

console.log('Deneme takvimi');
await expectError('geçmiş tarih olmaz', () => db.query(`select public.add_exam_plan('Eski', 'TYT', current_date - 10)`), 'EXAM_PLAN_BAD_DATE');
await expectError('kısa ad olmaz', () => db.query(`select public.add_exam_plan('X', 'TYT', current_date + 1)`), 'check');
const p2 = (await one(`select public.add_exam_plan('AYT Genel 2', 'AYT', current_date + 9) id`)).id;
await db.query(`select public.add_exam_plan(' TYT Genel 1 ', 'TYT', current_date + 2)`);
c = await cockpit();
check(c.exam_plans.length === 2 && c.exam_plans[0].name === 'TYT Genel 1', 'en yakın deneme önce', c.exam_plans);
await asUser(A.coach);
check((await rows(`select id from public.org_exam_plans`)).length === 2, 'koç kendi kurumunun takvimini okur');
await expectError('koç doğrudan yazamaz', () => db.query(`insert into public.org_exam_plans (org_id, tenant_id, name, planned_on) select org_id, tenant_id, 'X1', current_date from public.profiles where id = $1`, [A.coach]), 'permission');
await asUser(A.s1);
check((await rows(`select id from public.org_exam_plans`)).length === 0, 'öğrenci takvimi okuyamaz');
await asUser(B.admin);
check((await cockpit()).exam_plans.length === 0, 'öteki kurum görmez');
await expectError('öteki kurumun planı silinemez', () => db.query(`select public.delete_exam_plan($1)`, [p2]), 'EXAM_PLAN_NOT_FOUND');
await asUser(A.admin);
await db.query(`select public.delete_exam_plan($1)`, [p2]);
check((await cockpit()).exam_plans.length === 1, 'plan silindi');

console.log('Koç telefonu');
await expectError('biçim denetlenir', () => db.query(`select public.set_coach_phone($1, '0532')`, [A.coach]), 'check');
await expectError('öteki kurumun koçu olmaz', () => db.query(`select public.set_coach_phone($1, '+905321112233')`, [B.coach]), 'COACH_NOT_FOUND');
await db.query(`select public.set_coach_phone($1, '+905321112233')`, [A.coach]);
check((await cockpit()).coaches[0].phone === '+905321112233', 'telefon kokpitte');
await asUser(A.coach);
check((await rows(`select phone from public.coach_phones`)).length === 1, 'koç kendi numarasını görür');
await asUser(A.s1);
check((await rows(`select phone from public.coach_phones`)).length === 0, 'öğrenci koç telefonunu göremez');
await asUser(A.admin);
await db.query(`select public.set_coach_phone($1, '')`, [A.coach]);
check((await cockpit()).coaches[0].phone === null, 'boş numara siler');

console.log('Koça bildirim');
await db.query(`select public.notify_coach_about_student($1, '9 gündür giriş yok')`, [A.s2]);
await asUser(A.coach);
const n = await one(`select kind, data, ref_id from public.notifications where kind = 'coach_alert'`);
check(n && n.ref_id === A.s2 && n.data.reason === '9 gündür giriş yok' && n.data.route === `/coach/students/${A.s2}`,
  'koça bildirim düştü', n);
await asUser(A.admin);
await expectError('6 saat dolmadan tekrar gönderilmez', () => db.query(`select public.notify_coach_about_student($1, 'x')`, [A.s2]), 'COACH_ALERT_RECENT');
await asUser(B.admin);
await expectError('öteki kurumun öğrencisi olmaz', () => db.query(`select public.notify_coach_about_student($1, 'x')`, [A.s1]), 'STUDENT_NOT_FOUND');

console.log('Geri alma ve yeniden uygulama');
await asSuper();
const name = '20261106160000_admin_cockpit';
const later = migs.filter((f) => f > `${name}.sql`).map((f) => f.replace('.sql', '')).reverse();
for (const l of later) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.org_exam_plans') t`)).t === null, 'tablolar kaldırıldı');
await db.exec(read(migDir, `${name}.sql`));
for (const l of [...later].reverse()) await db.exec(read(migDir, `${l}.sql`));
await asUser(A.admin);
check((await cockpit()).students === 3, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
