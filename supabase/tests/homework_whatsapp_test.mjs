// Ödev PDF'i ve koç mesajı veliye WhatsApp'tan
// (20261111140000_homework_whatsapp).
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
async function signUp(code, name) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true,
      privacy_version: '1.0' })])).id;
}
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id, tenant_id`, [name]));
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org.id]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const student = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, `${name} Öğrenci`);
  return { org: org.id, tenant: org.tenant_id, admin, coach, student };
}
const A = await school('Bal Akademi', 'ADMINHW1');
const B = await school('Arı Kurs', 'ADMINHW2');
const items = JSON.stringify([{ subject_code: 'TYT_MAT', question_count: 30 }]);

console.log('Hazırlık');
await asUser(A.admin);
await db.query(`select public.set_guardian_phone($1, 'Ayşe Yılmaz', '+905321112233')`, [A.student]);
await asUser(A.coach);
const asg = (await one(`select public.send_assignment($1, 'Türev ödevi', $2::jsonb, date '2026-11-20') id`, [A.student, items])).id;
const asg2 = (await one(`select public.send_assignment($1, 'Tarihsiz', $2::jsonb) id`, [A.student, items])).id;

console.log('Ödev → veli');
let r = (await one(`select public.queue_homework_whatsapp($1) r`, [asg])).r;
check(r === 'queued', 'sıraya alındı', r);
await asSuper();
const m = await one(`select * from public.sms_outbox where assignment_id = $1`, [asg]);
check(m.template === 'odev_bildirimi' && m.phone === '+905321112233' && m.channel === 'whatsapp',
  'şablon ve veli telefonu', m);
check(JSON.stringify(m.params) === JSON.stringify(['Bal Akademi Koç', 'Bal Akademi Öğrenci', 'Türev ödevi', '20.11.2026', 'Bal Akademi']),
  'parametreler: koç, öğrenci, başlık, tarih, kurum', m.params);
check(m.media_path === `homework/${A.org}/${asg}.pdf`, 'PDF yolu sunucuda kurulur', m.media_path);
check(m.student_id === A.student && m.body.includes('Bal Akademi Koç, Bal Akademi Öğrenci adına'), 'metin ve öğrenci', m.body);
await asUser(A.coach);
check((await one(`select public.queue_homework_whatsapp($1) r`, [asg])).r === 'already', 'aynı ödev ikinci kez gitmez');
await asSuper();
check((await one(`select count(*)::int c from public.sms_outbox where assignment_id = $1`, [asg])).c === 1, 'tek satır');
await asUser(A.admin);
check((await one(`select public.queue_homework_whatsapp($1) r`, [asg2])).r === 'queued', 'müdür de gönderebilir');
await asSuper();
check((await one(`select params->>3 d from public.sms_outbox where assignment_id = $1`, [asg2])).d === 'belirtilmedi',
  'son tarihsiz ödev');

await asUser(B.coach);
await expectError('başka kurumun koçu gönderemez', () => db.query(`select public.queue_homework_whatsapp($1)`, [asg]), 'NOT_ALLOWED');
await asUser(A.student);
await expectError('öğrenci gönderemez', () => db.query(`select public.queue_homework_whatsapp($1)`, [asg]), 'NOT_ALLOWED');

console.log('Veli telefonu yok');
await asUser(B.coach);
const bAsg = (await one(`select public.send_assignment($1, 'Ödev', $2::jsonb) id`, [B.student, items])).id;
check((await one(`select public.queue_homework_whatsapp($1) r`, [bAsg])).r === 'no_phone', 'telefonsuz öğrenci: no_phone');
await expectError('koç mesajı da telefonsuz gitmez', () =>
  db.query(`select public.send_guardian_message($1, 'Merhaba')`, [B.student]), 'NO_PHONE');

console.log('Koç → veli');
await asUser(A.coach);
check((await one(`select public.send_guardian_message($1, $2) r`, [A.student, '  Bu hafta çok iyiydi.\nTebrikler.  '])).r === 'queued', 'gönderildi');
await asSuper();
const c = await one(`select * from public.sms_outbox where template = 'koc_mesaji'`);
check(JSON.stringify(c.params) === JSON.stringify(['Bal Akademi Öğrenci', 'Bal Akademi Koç', 'Bu hafta çok iyiydi.\nTebrikler.', 'Bal Akademi']),
  'parametreler: öğrenci, koç, metin, kurum', c.params);
await asUser(A.coach);
await expectError('boş metin', () => db.query(`select public.send_guardian_message($1, '   ')`, [A.student]), 'BAD_BODY');
await expectError('çok uzun metin', () => db.query(`select public.send_guardian_message($1, $2)`, [A.student, 'x'.repeat(901)]), 'BAD_BODY');
for (let i = 0; i < 4; i++) await db.query(`select public.send_guardian_message($1, $2)`, [A.student, `mesaj ${i}`]);
await expectError('24 saatte en çok 5', () => db.query(`select public.send_guardian_message($1, 'altıncı')`, [A.student]), 'GUARDIAN_MSG_LIMIT');
await asUser(B.coach);
await expectError('başka kurum yazamaz', () => db.query(`select public.send_guardian_message($1, 'x')`, [A.student]), 'NOT_ALLOWED');

console.log('Geçmiş');
await asUser(A.coach);
const hist = await rows(`select * from public.guardian_messages($1)`, [A.student]);
check(hist.length === 7 && hist.filter((h) => h.kind === 'homework').length === 2
  && hist.filter((h) => h.kind === 'coach').length === 5, 'ödev ve koç mesajları listelenir', hist.map((h) => h.kind));
check(hist.every((h) => h.status === 'queued') && hist.some((h) => h.sender === 'Bal Akademi Koç'), 'durum ve gönderen');
await asUser(B.admin);
await expectError('başka kurum geçmişi göremez', () => db.query(`select * from public.guardian_messages($1)`, [A.student]), 'NOT_ALLOWED');
await asUser(A.student);
await expectError('öğrenci geçmişi göremez', () => db.query(`select * from public.guardian_messages($1)`, [A.student]), 'NOT_ALLOWED');

console.log('Saklama');
await asSuper();
await db.query(`update public.sms_outbox set created_at = now() - interval '81 days' where assignment_id = $1`, [asg]);
check((await one(`select public.purge_homework_pdfs() n`)).n === 1, 'eski PDF temizlenir');
check((await one(`select path from public.storage_cleanup where bucket = 'homework'`)).path === `${A.org}/${asg}.pdf`,
  'silme kuyruğuna yazıldı');
check((await one(`select media_path from public.sms_outbox where assignment_id = $1`, [asg])).media_path === null, 'yol temizlendi');
check((await one(`select public.purge_homework_pdfs() n`)).n === 0, 'ikinci çalıştırma boş');

console.log('Öğrenci silinince');
await db.query(`delete from public.profiles where id = $1`, [A.student]);
check((await one(`select count(*)::int c from public.sms_outbox where template in ('odev_bildirimi', 'koc_mesaji')
  and org_id = $1`, [A.org])).c === 0, 'veli mesaj kayıtları da silinir');

console.log('Geri alma ve yeniden uygulama');
await db.exec(read(rbDir, '20261111140000_homework_whatsapp.down.sql'));
check((await one(`select to_regprocedure('public.queue_homework_whatsapp(uuid)') f`)).f === null, 'kaldırıldı');
check((await one(`select count(*)::int c from information_schema.columns where table_name = 'sms_outbox' and column_name = 'student_id'`)).c === 0,
  'sütunlar kaldırıldı');
await db.exec(read(migDir, '20261111140000_homework_whatsapp.sql'));
check((await one(`select to_regprocedure('public.send_guardian_message(uuid,text)') f`)).f !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
