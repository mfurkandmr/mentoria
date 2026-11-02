// Veli haftalık özeti (weekly_summary: kim görür, ne sayar, pazar bildirimi)
// ve rehberlik görüşme kaydı (kim yazar / görür / siler, koç değişince); geri alma.
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

const A = await school('Bal Akademi', 'ADMINWG1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');
await asUser(ahmet);
const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, 'Ayşe Demir');
await asUser(A.admin);
const coach2 = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Yeni Koç');
const B = await school('Yıldız', 'ADMINWG2');

await asSuper();
const tenantOf = `(select tenant_id from public.profiles where id = $2)`;
const subj = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
const topic = (await one(`select id from public.topics where subject_id = $1 limit 1`, [subj])).id;
// 3 gün çalıştı: iki gün soru, bir gün odak oturumu; 9 gün önceki sayılmaz.
for (const [k, n] of [[0, 30], [2, 20], [9, 50]]) {
  await db.query(`insert into public.question_logs (student_id, subject_id, topic_id, logged_on, correct, wrong, blank) values ($1, $2, $3, current_date - $4::int, $5, 0, 0)`, [ahmet, subj, topic, k, n]);
}
await db.query(`insert into public.study_sessions (student_id, started_at, duration_sec) values ($1, now() - interval '1 day', 3000), ($1, now(), 600)`, [ahmet]);
// Görüşmeler: bu hafta 1 yapıldı, 1 kaçırıldı; 30 gün önce kaçırılan sayılmaz.
const sch = (await one(`insert into public.meeting_schedules (coach_id, student_id, first_date, start_time, tenant_id) values ($1, $2, current_date - 40, '11:00', ${tenantOf}) returning id`, [A.coach, ahmet])).id;
for (const [k, st] of [[1, 'held'], [3, 'missed'], [30, 'missed']]) {
  await db.query(`insert into public.meeting_occurrences (schedule_id, occurs_on, student_id, tenant_id, status) values ($1, current_date - $4::int, $2, ${tenantOf}, $3)`, [sch, ahmet, st, k]);
}
// Ödev: bu hafta teslim 4 madde (3 yapıldı); 20 gün önce teslim olan sayılmaz.
const hw = async (due, items) => {
  const a = (await one(`insert into public.assignments (coach_id, student_id, title, due_on) values ($1, $2, 'Ödev', current_date - $3::int) returning id`, [A.coach, ahmet, due])).id;
  for (const done of items) await db.query(`insert into public.assignment_items (assignment_id, subject_id, done) values ($1, $2, $3)`, [a, subj, done]);
};
await hw(1, [true, true, false]);
await hw(5, [true]);
await hw(20, [false, false]);
// Denemeler: TYT 50 → 58 (son), AYT tek ve daha eski.
const exam = async (type, k, net) => {
  const e = (await one(`insert into public.exams (student_id, exam_type, name, taken_on) values ($1, $2, $3, current_date - $4::int) returning id`, [ahmet, type, `${type} D${k}`, k])).id;
  await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct, wrong) values ($1, $2, $3, 0)`, [e, subj, net]);
};
await exam('TYT', 20, 50); await exam('TYT', 4, 58); await exam('AYT', 10, 30);

console.log('Haftalık özet');
const summary = async (who, student = ahmet) => { await asUser(who); return (await one(`select public.weekly_summary($1) s`, [student])).s; };
const s = await summary(parent);
check(s.days === 3, 'çalıştığı gün 3', s.days);
check(s.questions === 50 && s.minutes === 60, 'bu haftanın soru ve dakikası', [s.questions, s.minutes]);
check(s.meetings_held === 1 && s.meetings_missed === 1, 'görüşme: 1 yapıldı, 1 kaçırıldı', [s.meetings_held, s.meetings_missed]);
check(s.homework_total === 4 && s.homework_done === 3, 'ödev 3 / 4', [s.homework_done, s.homework_total]);
check(s.exam_type === 'TYT' && Number(s.last_net) === 58 && Number(s.prev_net) === 50, 'son deneme TYT 58, önceki 50', s);
check((await summary(ahmet)).days === 3, 'öğrenci kendi özetini görür');
check((await summary(A.coach)).days === 3, 'koçu görür');
check((await summary(A.admin)).days === 3, 'müdürü görür');
await asUser(can);
await expectError('sınıf arkadaşı göremez', () => db.query(`select public.weekly_summary($1)`, [ahmet]), 'NOT_ALLOWED');
await asUser(B.coach);
await expectError('başka kurum göremez', () => db.query(`select public.weekly_summary($1)`, [ahmet]), 'NOT_ALLOWED');
await asUser(ahmet);
await expectError('iç fonksiyon doğrudan çağrılamaz', () => db.query(`select public.weekly_summary_data($1)`, [ahmet]), 'permission denied');
const empty = await summary(A.coach, can);
check(empty.days === 0 && empty.homework_total === 0 && empty.last_net === null && empty.exam_type === null, 'verisi olmayan öğrenci: sıfırlar ve deneme yok', empty);

console.log('Pazar bildirimi');
await asSuper();
const sent = (await one(`select public.send_parent_weekly_reports() n`)).n;
const note = (await one(`select data from public.notifications where user_id = $1 and kind = 'weekly_report'`, [parent])).data;
check(sent === 1 && note.days === 3 && note.homework_done === 3 && note.meetings_missed === 1 && Number(note.last_net) === 58, 'bildirim kartla aynı veriyi taşır', note);
check(note.child === 'Ahmet' && note.route.includes(ahmet), 'eski alanlar (child, route) korunur');
check((await one(`select public.send_parent_weekly_reports() n`)).n === 0, 'aynı hafta ikinci kez gitmez');
await db.query(`delete from public.notifications where kind = 'weekly_report'`);
await db.query(`update public.organizations set license_expires_at = now() - interval '1 day' where id = $1`, [A.org]);
check((await one(`select public.send_parent_weekly_reports() n`)).n === 0, 'lisansı biten kurumun velisine gitmez');
await db.query(`update public.organizations set license_expires_at = null where id = $1`, [A.org]);

console.log('Rehberlik kaydı');
const log = (student, extra = {}) => db.query(
  `insert into public.guidance_logs (student_id, met_on, kind, topics, note, next_step, author_name)
   values ($1, current_date - $2::int, $3, $4, $5, $6, 'sahte') returning id, author_id, author_name`,
  [student, extra.ago ?? 0, extra.kind ?? 'in_person', extra.topics ?? ['motivation'], extra.note ?? 'Deneme sonrası moral düşük.', extra.next ?? null]);
await asUser(A.coach);
const g1 = (await log(ahmet, { topics: ['motivation', 'time'], next: 'Haftaya plan kontrolü' })).rows[0];
check(g1.author_id === A.coach && g1.author_name === 'Bal Akademi Koç', 'yazan ve adı sunucuda yazılır', g1);
await log(ahmet, { ago: 7, kind: 'parent', topics: ['family'] });
await expectError('gelecek tarih olmaz', () => log(ahmet, { ago: -1 }), 'GUIDANCE_BAD_DATE');
await expectError('bilinmeyen etiket olmaz', () => log(ahmet, { topics: ['saglik'] }));
await expectError('boş not olmaz', () => log(ahmet, { note: '   ' }));
await asUser(A.admin);
await log(ahmet, { kind: 'phone', topics: ['university'] });
ok('müdür de yazar');
await asUser(B.coach);
await expectError('başka kurumun koçu yazamaz', () => log(ahmet));
await asUser(ahmet);
await expectError('öğrenci yazamaz', () => log(ahmet));

const seen = async (who) => { await asUser(who); return (await one(`select count(*)::int c from public.guidance_logs where student_id = $1`, [ahmet])).c; };
check(await seen(A.coach) === 3, 'koçu tüm geçmişi görür');
check(await seen(A.admin) === 3, 'müdür görür');
check(await seen(ahmet) === 0, 'öğrenci görmez');
check(await seen(parent) === 0, 'veli görmez');
check(await seen(coach2) === 0, 'öğrencinin koçu olmayan koç görmez');
check(await seen(B.admin) === 0, 'başka kurum görmez');

await asUser(A.coach);
await expectError('değiştirilemez', () => db.query(`update public.guidance_logs set note = 'x' where id = $1`, [g1.id]), 'permission denied');

console.log('Koç değişince kayıt kurumda kalır');
await asSuper();
await db.query(`update public.coach_students set coach_id = $1 where student_id = $2`, [coach2, ahmet]);
check(await seen(coach2) === 3, 'yeni koç tüm geçmişi görür');
check(await seen(A.coach) === 0, 'eski koç artık göremez');
await asSuper();
await db.query(`delete from public.profiles where id = $1`, [A.coach]);
const kept = await one(`select author_id, author_name from public.guidance_logs where id = $1`, [g1.id]);
check(kept.author_id === null && kept.author_name === 'Bal Akademi Koç', 'eski koçun hesabı silinse de kaydı ve adı kalır', kept);

console.log('Silme');
await asUser(coach2);
const g2 = (await log(ahmet)).rows[0].id;
let r = await db.query(`delete from public.guidance_logs where id = $1`, [g1.id]);
check(r.affectedRows === 0, 'başkasının kaydını silemez');
r = await db.query(`delete from public.guidance_logs where id = $1`, [g2]);
check(r.affectedRows === 1, 'kendi kaydını 24 saat içinde siler');
const g4 = (await log(ahmet)).rows[0].id;
await asSuper();
await db.query(`update public.guidance_logs set created_at = now() - interval '2 days' where id = $1`, [g4]);
await asUser(coach2);
r = await db.query(`delete from public.guidance_logs where id = $1`, [g4]);
check(r.affectedRows === 0, '24 saatten sonra yazan silemez');
await asUser(A.admin);
r = await db.query(`delete from public.guidance_logs where id = $1`, [g4]);
check(r.affectedRows === 1, 'müdür her zaman silebilir');

console.log('Öğrenci silinince');
await asSuper();
await db.query(`delete from public.profiles where id = $1`, [ahmet]);
check((await one(`select count(*)::int c from public.guidance_logs`)).c === 0, 'kayıtları da silinir');

console.log('Geri alma ve yeniden uygulama');
for (const name of ['20261031130000_guidance_logs', '20261031120000_weekly_summary']) {
  await db.exec(read(rbDir, `${name}.down.sql`));
}
check((await one(`select to_regclass('public.guidance_logs') t`)).t === null, 'tablo kalktı');
check((await one(`select count(*)::int c from pg_proc where proname = 'weekly_summary'`)).c === 0, 'özet fonksiyonu kalktı');
check((await one(`select count(*)::int c from pg_proc where proname = 'send_parent_weekly_reports'`)).c === 1, 'eski bildirim fonksiyonu yerinde');
for (const name of ['20261031120000_weekly_summary', '20261031130000_guidance_logs']) {
  await db.exec(read(migDir, `${name}.sql`));
}
ok('yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
