// Koç–öğrenci görüşmeleri: koç planlar (tek seferlik / haftalık), öğrenci,
// velisi ve müdür görür; koç durumunu işaretler; görüşmeye 24 saat kala
// öğrenciye tek bir hatırlatma bildirimi düşer; dershane izolasyonu ve
// geri alma.
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
const count = async (sql, p = []) => (await one(sql, p)).c;
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

const A = await school('Bal Akademi', 'ADMINMT1');
await asUser(A.admin);
const coach2 = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Bal Koç 2');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');
await asUser(ahmet);
const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, 'Ahmet Veli');
const B = await school('Yıldız', 'ADMINMT2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

// Tarihler bugüne göre (Türkiye saati): rutin 14 gün önce başlamış, haftalık.
await asSuper();
const today = (await one(`select ((now() at time zone 'Europe/Istanbul')::date)::text d`)).d;
const day = async (offset) => (await one(`select ($1::date + $2::int)::text d`, [today, offset])).d;
const at = async (offset, hours) => (await one(
  `select ((($1::date + $2::int) + time '11:00') at time zone 'Europe/Istanbul' + make_interval(hours => $3::int)) t`,
  [today, offset, hours])).t;
const start = await day(-14);

// --- Koç planlar ---
await asUser(A.coach);
const sched = (await one(
  `insert into public.meeting_schedules (coach_id, student_id, first_date, start_time, note)
   values ($1, $2, $3, '11:00', 'Haftalık değerlendirme') returning id, tenant_id`,
  [A.coach, ahmet, start]));
await asSuper();
const tenantA = (await one(`select tenant_id from public.organizations where id = $1`, [A.org])).tenant_id;
check(sched?.id && sched.tenant_id === tenantA, 'koç öğrencisi için haftalık görüşme planlar (tenant_id sunucuda)', sched);

await asUser(coach2);
await expectError('başka koç bu öğrenciye görüşme planlayamaz', () => db.query(
  `insert into public.meeting_schedules (coach_id, student_id, first_date, start_time) values ($1, $2, $3, '10:00')`,
  [coach2, ahmet, today]));
await asUser(A.coach);
await expectError('koç başka koç adına planlayamaz', () => db.query(
  `insert into public.meeting_schedules (coach_id, student_id, first_date, start_time) values ($1, $2, $3, '10:00')`,
  [coach2, ahmet, today]));
await asUser(ahmet);
await expectError('öğrenci görüşme planlayamaz', () => db.query(
  `insert into public.meeting_schedules (coach_id, student_id, first_date, start_time) values ($1, $2, $3, '10:00')`,
  [A.coach, ahmet, today]));
await asUser(A.coach);
await expectError('süre sınırı (10–180 dk)', () => db.query(
  `insert into public.meeting_schedules (coach_id, student_id, first_date, start_time, duration_min) values ($1, $2, $3, '10:00', 500)`,
  [A.coach, ahmet, today]), 'check');

// --- Kim görür ---
const sees = async (who) => { await asUser(who); return count(`select count(*)::int c from public.meeting_schedules`); };
check(await sees(ahmet) === 1, 'öğrenci kendi görüşmesini görür');
check(await sees(parent) === 1, 'veli çocuğunun görüşmesini görür');
check(await sees(A.admin) === 1, 'kurum müdürü görüşmeyi görür');
check(await sees(A.coach) === 1, 'koç kendi planını görür');
check(await sees(coach2) === 0, 'başka koç görmez');
check(await sees(can) === 0, 'başka öğrenci görmez');
check(await sees(B.admin) === 0, 'başka dershanenin müdürü görmez');
check(await sees(B.coach) === 0, 'başka dershanenin koçu görmez');
await asAnon();
await expectError('giriş yapmayan okuyamaz', () => db.query(`select * from public.meeting_schedules`));

// --- Durum işaretleme ---
await asUser(A.coach);
await db.query(`select public.set_meeting_status($1, $2, 'held')`, [sched.id, await day(-7)]);
await asUser(A.admin);
const occ = await one(`select status, marked_by, student_id, tenant_id from public.meeting_occurrences where schedule_id = $1`, [sched.id]);
check(occ?.status === 'held' && occ.marked_by === A.coach && occ.student_id === ahmet && occ.tenant_id === tenantA,
  'koç geçen haftaki görüşmeyi "yapıldı" işaretler; müdür görür', occ);
await asUser(A.coach);
await expectError('görüşme olmayan gün işaretlenemez', async () =>
  db.query(`select public.set_meeting_status($1, $2, 'held')`, [sched.id, await day(-6)]), 'NO_MEETING_THAT_DAY');
await expectError('rutinin başlangıcından önceki gün işaretlenemez', async () =>
  db.query(`select public.set_meeting_status($1, $2, 'held')`, [sched.id, await day(-21)]), 'NO_MEETING_THAT_DAY');
await expectError('gelecekteki görüşme "yapıldı" işaretlenemez', async () =>
  db.query(`select public.set_meeting_status($1, $2, 'held')`, [sched.id, await day(7)]), 'MEETING_IN_FUTURE');
await expectError('geçersiz durum', async () =>
  db.query(`select public.set_meeting_status($1, $2, 'maybe')`, [sched.id, await day(-7)]), 'INVALID_STATUS');
await db.query(`select public.set_meeting_status($1, $2, 'cancelled')`, [sched.id, await day(7)]);
ok('gelecekteki görüşme iptal edilebilir');
await asUser(coach2);
await expectError('başka koç durum işaretleyemez', async () =>
  db.query(`select public.set_meeting_status($1, $2, 'missed')`, [sched.id, await day(-7)]), 'NOT_ALLOWED');
await asUser(ahmet);
await expectError('öğrenci durum işaretleyemez', async () =>
  db.query(`select public.set_meeting_status($1, $2, 'missed')`, [sched.id, await day(-7)]), 'NOT_ALLOWED');
await expectError('görüşme kaydına doğrudan yazılamaz', () => db.query(
  `insert into public.meeting_occurrences (schedule_id, occurs_on, student_id, status) values ($1, $2, $3, 'held')`,
  [sched.id, today, ahmet]));
await asUser(A.coach);
await expectError('koç da doğrudan yazamaz (yalnızca fonksiyonla)', async () =>
  db.query(`update public.meeting_occurrences set status = 'missed'`));
check(await count(`select count(*)::int c from public.meeting_occurrences where status = 'held'`) === 1, 'doğrudan güncelleme etkisiz');

// --- 24 saat kala hatırlatma ---
await asUser(A.coach);
await expectError('koç hatırlatma fonksiyonunu çağıramaz', () => db.query(`select public.send_meeting_reminders()`));
await asSuper();
const remind = async (p) => (await one(`select public.send_meeting_reminders($1::timestamptz) n`, [p])).n;
check(await remind(await at(14, -25)) === 0, '25 saat kala hatırlatma gitmez');
check(await remind(await at(14, -23)) === 1, '23 saat kala hatırlatma gider');
const n = await one(`select user_id, data, ref_id, tenant_id from public.notifications where kind = 'meeting'`);
check(n?.user_id === ahmet && n.ref_id === sched.id && n.data.coach === 'Bal Akademi Koç'
  && n.data.route === '/student' && n.tenant_id === tenantA, 'bildirim öğrenciye (koç adı, saat ve rota)', n);
check(new Date(n?.data.at).getTime() === new Date(await at(14, 0)).getTime(), 'bildirimdeki saat görüşme saati (Türkiye 11:00)', n?.data.at);
check(await remind(await at(14, -1)) === 0, 'aynı görüşme için ikinci hatırlatma gitmez');
check(await remind(await at(7, -23)) === 0, 'iptal edilen görüşme için hatırlatma gitmez');
check(await remind(await at(14, 1)) === 0, 'geçmiş görüşme için hatırlatma gitmez');
check(await count(`select count(*)::int c from public.notifications where kind = 'meeting' and user_id <> $1`, [ahmet]) === 0,
  'veli, koç ya da başka öğrenciye hatırlatma gitmez');

// --- Tek seferlik görüşme ve rutini bitirme ---
await asUser(A.coach);
const onceId = (await one(
  `insert into public.meeting_schedules (coach_id, student_id, first_date, start_time, repeat_weekly)
   values ($1, $2, $3, '11:00', false) returning id`, [A.coach, ahmet, await day(30)])).id;
await asSuper();
check(await remind(await at(30, -2)) === 1, 'tek seferlik görüşmeye de hatırlatma gider');
check(await remind(await at(37, -2)) === 0, 'tek seferlik görüşme ertesi hafta tekrarlanmaz');
await asUser(A.coach);
await db.query(`update public.meeting_schedules set until_date = $2 where id = $1`, [sched.id, await day(20)]);
await asSuper();
check(await remind(await at(21, -2)) === 0, 'rutin bitince sonraki görüşmelere hatırlatma gitmez');
await asUser(A.coach);
check(await count(`select count(*)::int c from public.meeting_occurrences where schedule_id = $1 and status = 'held'`, [sched.id]) === 1,
  'rutin bitince geçmiş kayıtlar kalır');
await asUser(coach2);
await db.query(`delete from public.meeting_schedules where id = $1`, [onceId]);
await asSuper();
check(await count(`select count(*)::int c from public.meeting_schedules where id = $1`, [onceId]) === 1, 'başka koç görüşmeyi silemez');
await asUser(A.coach);
await db.query(`delete from public.meeting_schedules where id = $1`, [onceId]);
check(await count(`select count(*)::int c from public.meeting_schedules where id = $1`, [onceId]) === 0, 'koç kendi görüşmesini siler');

// --- Öğrenci silinince görüşmeleri de gider ---
await asUser(A.coach);
await db.query(`select public.delete_student_account($1)`, [ahmet]);
await asSuper();
check(await count(`select count(*)::int c from public.meeting_schedules where student_id = $1`, [ahmet]) === 0
  && await count(`select count(*)::int c from public.meeting_occurrences where student_id = $1`, [ahmet]) === 0,
  'öğrenci silinince görüşmeleri de silinir');

// --- Geri alma ve yeniden uygulama ---
const mig = migs.find((f) => f.includes('_meetings'));
await db.exec(read(rbDir, mig.replace('.sql', '.down.sql')));
const gone = await one(`select to_regclass('public.meeting_schedules') s, to_regclass('public.meeting_occurrences') o,
  to_regprocedure('public.send_meeting_reminders(timestamptz)') f,
  (select count(*)::int from public.notifications where kind = 'meeting') n`);
check(gone.s === null && gone.o === null && gone.f === null && gone.n === 0, 'geri alma: tablolar, fonksiyonlar ve bildirimler kalktı', gone);
await expectError('geri alma: eski bildirim türü kısıtı geri geldi', async () =>
  db.query(`insert into public.notifications (user_id, kind) values ($1, 'meeting')`, [can]), 'notifications_kind_check');
await db.query(`insert into public.notifications (user_id, kind) values ($1, 'deletion_request')`, [A.coach]);
ok('geri alma sonrası önceki bildirim türleri çalışır');
await db.exec(read(migDir, mig));
await asUser(A.coach);
await db.query(`insert into public.meeting_schedules (coach_id, student_id, first_date, start_time) values ($1, $2, $3, '09:30')`,
  [A.coach, can, today]);
check(await count(`select count(*)::int c from public.meeting_schedules`) === 1, 'yeniden uygulama başarılı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
