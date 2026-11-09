// Kurum sınavı sonucu velilere SMS (20261107120000_exam_result_sms).
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
  const student2 = await signUp(sCode, `${name} Öğrenci İki`);
  await asUser(student);
  const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, `${name} Veli`,
    { guardian_approval: true });
  return { org, admin, coach, student, student2, parent };
}


const A = await school('Bal Akademi', 'ADMINRS1');
const B = await school('Arı Kurs', 'ADMINRS2');
await asUser(A.coach);
const s3 = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, 'Telefonsuz Öğrenci');

console.log('Hazırlık');
await asUser(A.admin);
const cls = (await one(`insert into public.classrooms (name) values ('12-A') returning id`)).id;
await db.query(`insert into public.classroom_students (classroom_id, student_id) values ($1, $2), ($1, $3)`,
  [cls, A.student, A.student2]);
await db.query(`select public.set_guardian_phone($1, 'Ayşe', '+905321112233')`, [A.student]);
await db.query(`select public.set_guardian_phone($1, 'Mehmet', '+905321114455')`, [A.student2]);
check((await one(`select public.exam_result_sms_enabled() v`)).v === true, 'varsayılan açık');

const def = (name) => JSON.stringify({
  name, exam_type: 'TYT', kind: 'deneme', taken_on: '2026-11-01',
  wrong_penalty: true, penalty_ratio: 0.25, classrooms: [cls],
  subjects: [{ subject: 'TYT_MAT', count: 4, weight: 1 }, { subject: 'TYT_TUR', count: 2, weight: 1 }],
  items: [
    ...[1, 2, 3, 4].map((no) => ({ subject: 'TYT_MAT', no, correct: 'A' })),
    ...[1, 2].map((no) => ({ subject: 'TYT_TUR', no, correct: 'A' })),
  ],
});
const good = { TYT_MAT: ['A', 'A', 'A', 'B'], TYT_TUR: ['A', 'A'] };
const weak = { TYT_MAT: ['A', 'B', null, null] };
const outbox = () => rows(`select phone, body, exam_id from public.sms_outbox where exam_id is not null order by phone`);

console.log('Taslakta SMS yok, yayınlanınca her veliye bir kez');
await asUser(A.coach);
const key = (await one(`select public.save_exam(null, $1) id`, [def('Kurum Denemesi 1')])).id;
const imp = (await one(`select public.start_exam_import($1, 'optik.xlsx', '{}') id`, [key])).id;
await db.query(`select public.import_exam_sheets($1, $2)`, [imp, JSON.stringify([
  { student_id: A.student, booklet: 'A', answers: good },
  { student_id: A.student2, booklet: 'A', answers: weak },
  { student_id: s3, booklet: 'A', answers: weak },
])]);
await db.query(`select public.finish_exam_import($1)`, [imp]);
await asSuper();
check((await outbox()).length === 0, 'taslak sınavda SMS çıkmaz');
await asUser(A.coach);
await db.query(`select public.publish_exam($1)`, [key]);
await asSuper();
let o = await outbox();
check(o.length === 2, 'yayınlanınca telefonu olan 2 veliye (telefonsuz atlanır)', o);
const first = o.find((r) => r.phone === '+905321112233');
check(first && first.body === 'Bal Akademi: Bal Akademi Öğrenci - Kurum Denemesi 1 sonucu: 4,75 net, kurum sırası 1/3. Tür 2D 0Y 2,00; Mat 3D 1Y 2,75. Ayrıntılar uygulamada.',
  'metin: kurum, öğrenci, sınav, net, kurum sırası, kısa ders satırları', first);
check(o.every((r) => r.body.startsWith('Bal Akademi: ')), 'başka kurumun adı yok');

console.log('Yeniden puanlama ve tekrar yükleme tekrar göndermez');
await asUser(A.coach);
await db.query(`select public.save_exam($1, $2)`, [key, def('Kurum Denemesi 1')]);
const imp2 = (await one(`select public.start_exam_import($1, 'optik2.xlsx', '{}') id`, [key])).id;
await db.query(`select public.import_exam_sheets($1, $2)`, [imp2, JSON.stringify([
  { student_id: A.student, booklet: 'A', answers: weak }])]);
await db.query(`select public.finish_exam_import($1)`, [imp2]);
await asSuper();
check((await outbox()).length === 2, 'anahtar düzeltme ve yeniden yükleme yeni SMS üretmez');

console.log('Yayındaki sınava sonradan gelen öğrenci');
await asUser(A.admin);
await db.query(`select public.set_guardian_phone($1, 'Fatma', '+905321116677')`, [s3]);
// s3'ün denemesi var ama SMS'i yoktu (telefon yoktu); yeni optikte gider.
await asUser(A.coach);
await db.query(`select public.submit_optic($1, $2, $3, 'A')`, [key, s3, JSON.stringify(good)]);
await asSuper();
check((await outbox()).length === 3, 'kamera okumasıyla gelen sonuç da veliye gider');

console.log('Kapalıyken gönderilmez; eski denemeler toplu gitmez');
await asUser(A.coach);
await expectError('koç ayarı değiştiremez', () => db.query(`select public.set_exam_result_sms(false)`), 'NOT_ALLOWED');
await asUser(A.admin);
await db.query(`select public.set_exam_result_sms(false)`);
check((await one(`select public.exam_result_sms_enabled() v`)).v === false, 'müdür kapattı');
await asUser(A.coach);
const key2 = (await one(`select public.save_exam(null, $1) id`, [def('Kurum Denemesi 2')])).id;
await db.query(`select public.submit_optic($1, $2, $3, 'A')`, [key2, A.student, JSON.stringify(good)]);
await db.query(`select public.publish_exam($1)`, [key2]);
await asSuper();
check((await outbox()).length === 3, 'kapalıyken SMS çıkmaz');
await db.query(`update public.exams set created_at = now() - interval '5 days' where batch_id = $1`, [key2]);
await asUser(A.admin);
await db.query(`select public.set_exam_result_sms(true)`);
await asUser(A.coach);
await db.query(`select public.save_exam($1, $2)`, [key2, def('Kurum Denemesi 2')]);
await asSuper();
check((await outbox()).length === 3, 'açılınca 3 günden eski denemeler için SMS çıkmaz');

console.log('Yetki');
await asUser(A.student);
await expectError('öğrenci ayarı okuyamaz', () => db.query(`select public.exam_result_sms_enabled()`), 'NOT_ALLOWED');
await expectError('iç fonksiyon çağrılamaz', () => db.query(`select public._queue_exam_result_sms($1)`, [key]));
await asUser(B.admin);
check((await one(`select public.exam_result_sms_enabled() v`)).v === true, 'diğer kurumun ayarı ayrı');
check((await rows(`select 1 from public.sms_outbox where exam_id is not null`)).length === 0, 'diğer kurum SMS kayıtlarını görmez');

console.log('Geri alma ve yeniden uygulama');
await asSuper();
const name = '20261107120000_exam_result_sms';
const later = migs.filter((f) => f > `${name}.sql`).map((f) => f.replace('.sql', '')).reverse();
for (const l of later) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check(!(await one(`select 1 x from information_schema.columns where table_name = 'sms_outbox' and column_name = 'exam_id'`)), 'sütunlar kalktı');
await db.exec(read(migDir, `${name}.sql`));
for (const l of [...later].reverse()) await db.exec(read(migDir, `${l}.sql`));
check((await one(`select public._queue_exam_result_sms($1) n`, [key])).n >= 0, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
