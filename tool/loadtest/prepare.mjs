// Mentoria-Test'i gerçekçi yük testine hazırlar (yalnızca test projesi):
//  * yuk-* test hesaplarına bilinen parola (LT_PASSWORD; yoksa üretilir)
//  * 25 koç (öğrenciler koç başına 40), kurum kredisi
//  * 10 öğretmen, 5 sınıf (200'er öğrenci), 5 gün × 8 saat yayında program
//  * öğretmenlere soru çözümü oturumları
// Tekrar çalıştırılabilir: var olanı yeniden yaratmaz.
import crypto from 'node:crypto';
import fs from 'node:fs';
import { connect, envFile, readEnv } from './db.mjs';

const env = readEnv();
let pw = env.LT_PASSWORD;
if (!pw) {
  pw = crypto.randomBytes(12).toString('base64url');
  fs.appendFileSync(envFile, `\nLT_PASSWORD=${pw}\n`);
  console.log('Yeni test parolası .env.local dosyasına yazıldı.');
}

const db = await connect();
const one = async (q, p = []) => (await db.query(q, p)).rows[0];
const step = (m) => console.log('-', m);

const admin = await one(`select u.id, p.org_id from auth.users u join public.profiles p on p.id = u.id
  where u.email = 'yuk-admin@example.com'`);
if (!admin) throw new Error('yuk-admin bulunamadı');
const org = admin.org_id;
// Tetikleyiciler auth.uid() ile kurumu bulur: müdür gibi davran.
await db.query(`select set_config('request.jwt.claim.sub', $1, false),
  set_config('request.jwt.claims', json_build_object('sub', $1::text, 'role', 'authenticated')::text, false)`, [admin.id]);

step('parolalar');
await db.query(`update auth.users set encrypted_password = extensions.crypt($1, extensions.gen_salt('bf')),
  email_confirmed_at = coalesce(email_confirmed_at, now()) where email like 'yuk-%@example.com'`, [pw]);

step('kurum kredisi ve lisans');
await db.query(`update public.organizations set credit_balance = greatest(credit_balance, 5000),
  license_expires_at = null where id = $1`, [org]).catch(async () => {
  await db.query(`update public.organizations set credit_balance = greatest(credit_balance, 5000) where id = $1`, [org]);
});

step('koçlar');
const coachCount = Number((await one(`select count(*) c from public.profiles where org_id = $1 and role = 'coach'`, [org])).c);
if (coachCount < 25) {
  await db.query(`insert into public.invite_codes (code, org_id, target_role, max_uses, created_by)
    values ('YUKKOC25', $1, 'coach', 60, $2) on conflict (code) do nothing`, [org, admin.id]);
  for (let i = coachCount + 1; i <= 25; i++) {
    const email = `yuk-koc-${i}@example.com`;
    let u = await one('select id from auth.users where email = $1', [email]);
    if (!u) u = await one(`insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
        confirmation_token, recovery_token, email_change_token_new, email_change)
      values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
        $1, extensions.crypt($2, extensions.gen_salt('bf')), now(),
        '{"provider":"email","providers":["email"]}', $3, now(), now(), '', '', '', '')
      returning id`,
    [email, pw, JSON.stringify({ invite_code: 'YUKKOC25', full_name: `Yük Koç ${i}`,
      kvkk_consent: true, privacy_version: '1.0' })]);
    await db.query(`insert into auth.identities (id, user_id, provider_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at)
      select gen_random_uuid(), $1::uuid, $3::text, jsonb_build_object('sub', $3::text, 'email', $2::text,
        'email_verified', true), 'email', now(), now(), now()
      where not exists (select 1 from auth.identities where user_id = $1::uuid)`, [u.id, email, String(u.id)]);
  }
}
const coaches = (await db.query(`select id from public.profiles where org_id = $1 and role = 'coach' order by created_at`, [org])).rows.map((r) => r.id);
const students = (await db.query(`select id from public.profiles where org_id = $1 and role = 'student' order by created_at`, [org])).rows.map((r) => r.id);
step(`${coaches.length} koç, ${students.length} öğrenci: koç başına ~${Math.round(students.length / coaches.length)}`);
await db.query('delete from public.coach_students where org_id = $1', [org]);
await db.query(`insert into public.coach_students (coach_id, student_id, org_id)
  select ($2::uuid[])[((row_number() over (order by s) - 1) % array_length($2::uuid[], 1)) + 1], s, $1
  from unnest($3::uuid[]) s`, [org, coaches, students]);

step('ders programı');
const hasSchedule = await one(`select id from public.schedules where org_id = $1 and status = 'published'`, [org]);
if (!hasSchedule) {
  const branches = ['Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'Tarih', 'Coğrafya', 'Geometri', 'Edebiyat', 'İngilizce'];
  const teachers = [];
  for (const [i, b] of branches.entries()) {
    teachers.push((await one(`insert into public.teachers (org_id, full_name, branches) values ($1, $2, $3) returning id`,
      [org, `Yük Öğretmen ${i + 1}`, [b]])).id);
  }
  const slots = [];
  for (let d = 1; d <= 5; d++) {
    for (let k = 1; k <= 8; k++) {
      const start = 9 * 60 + (k - 1) * 50;
      const hm = (m) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
      slots.push({ d, k, id: (await one(`insert into public.time_slots (org_id, day, seq, start_time, end_time)
        values ($1, $2, $3, $4, $5) returning id`, [org, d, k, hm(start), hm(start + 40)])).id });
    }
  }
  const classes = [];
  for (let c = 0; c < 5; c++) {
    classes.push((await one(`insert into public.classrooms (org_id, name, level) values ($1, $2, '12') returning id`,
      [org, `12-${'ABCDE'[c]}`])).id);
  }
  await db.query(`insert into public.classroom_students (classroom_id, student_id, org_id)
    select ($2::uuid[])[((row_number() over (order by s) - 1) % 5) + 1], s, $1 from unnest($3::uuid[]) s`,
  [org, classes, students]);
  const sch = (await one(`insert into public.schedules (org_id, name, term) values ($1, 'Yük testi', '2026-2027') returning id`, [org])).id;
  for (const s of slots) {
    for (let c = 0; c < 5; c++) {
      const t = (c + s.k + s.d) % teachers.length;
      await db.query(`insert into public.schedule_entries (org_id, schedule_id, teacher_id, classroom_id, time_slot_id, branch)
        values ($1, $2, $3, $4, $5, $6)`, [org, sch, teachers[t], classes[c], s.id, branches[t]]);
    }
  }
  await db.query(`update public.schedules set status = 'published' where id = $1`, [sch]);

  step('soru çözümü oturumları');
  for (const [i, t] of teachers.entries()) {
    for (const d of [1 + (i % 5), 1 + ((i + 2) % 5)]) {
      await db.query(`insert into public.tutoring_sessions (org_id, teacher_id, kind, day, start_time, end_time, capacity)
        values ($1, $2, 'question_solving', $3, '16:00', '17:00', 8)`, [org, t, d]);
    }
  }
}

step('istatistikler');
await db.query('analyze');
const sum = await one(`select
  (select count(*) from public.question_logs) logs,
  (select count(*) from public.exams) exams,
  (select count(*) from public.schedule_entries) entries,
  (select count(*) from public.tutoring_sessions) sessions`);
console.log(sum);
await db.end();
