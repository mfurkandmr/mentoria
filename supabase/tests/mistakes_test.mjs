// Hata defteri (aralıklı tekrar, fotoğraf yolu, kimin gördüğü), günlük tekrar
// hatırlatması ve velilere haftalık rapor; geri alma / yeniden uygulama.
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

const A = await school('Bal Akademi', 'ADMINHD1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');
await asUser(ahmet);
const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, 'Ahmet Veli');
const B = await school('Yıldız', 'ADMINHD2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

await asSuper();
const today = (await one(`select ((now() at time zone 'Europe/Istanbul')::date)::text d`)).d;
const plus = async (n) => (await one(`select ($1::date + $2::int)::text d`, [today, n])).d;
const sameDay = async (a, b) => (await one(`select $1::date = $2::date ok`, [a, b])).ok;
const mat = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
const topic = (await one(`select id from public.topics where subject_id = $1 order by id limit 1`, [mat])).id;

console.log('Kart ekleme');
await asUser(ahmet);
const card = await one(`insert into public.mistake_cards (student_id, subject_id, topic_id, note, photo_path)
  values ($1, $2, $3, 'türev sorusu', $4) returning *`, [ahmet, mat, topic, `${ahmet}/a1.jpg`]);
check(card.stage === 0, 'yeni kart: aşama 0');
check(await sameDay(card.due_on, await plus(1)), 'ilk tekrar yarın');
await expectError('başkası adına kart eklenemez', () => db.query(`insert into public.mistake_cards (student_id, subject_id) values ($1, $2)`, [can, mat]));
await expectError('fotoğraf yolu biçimi denetlenir', () => db.query(`insert into public.mistake_cards (student_id, subject_id, photo_path) values ($1, $2, '../x.jpg')`, [ahmet, mat]));
await expectError('dershane kimliği değiştirilemez', () => db.query(`update public.mistake_cards set tenant_id = gen_random_uuid() where id = $1`, [card.id]), 'permission denied');
await asUser(A.coach);
await expectError('koç kart ekleyemez', () => db.query(`insert into public.mistake_cards (student_id, subject_id) values ($1, $2)`, [ahmet, mat]));

console.log('Kimler görür');
const seen = async (who) => { await asUser(who); return (await one(`select count(*)::int c from public.mistake_cards`)).c; };
check(await seen(ahmet) === 1, 'öğrenci kendi kartını görür');
check(await seen(A.coach) === 1, 'koçu görür');
check(await seen(A.admin) === 1, 'kurum müdürü görür');
check(await seen(parent) === 1, 'velisi görür');
check(await seen(can) === 0, 'sınıf arkadaşı göremez');
check(await seen(zeynep) === 0, 'başka dershane göremez');
await asUser(A.coach);
const upd = await db.query(`update public.mistake_cards set note = 'x' where id = $1 returning id`, [card.id]);
check(upd.rows.length === 0, 'koç kartı değiştiremez');

console.log('Aralıklı tekrar: 1 → 3 → 7 → 21 gün');
await asUser(ahmet);
const review = (solved) => one(`select * from public.review_mistake($1, $2)`, [card.id, solved]);
let r = await review(true);
check(r.stage === 1 && await sameDay(r.due_on, await plus(3)), '1. tekrar doğru: 3 gün sonra', r);
r = await review(true);
check(r.stage === 2 && await sameDay(r.due_on, await plus(7)), '2. tekrar doğru: 7 gün sonra');
r = await review(false);
check(r.stage === 0 && r.fails === 1 && await sameDay(r.due_on, await plus(1)), 'yanlış: başa döner, yarın');
for (let i = 0; i < 3; i++) r = await review(true);
check(r.stage === 3 && await sameDay(r.due_on, await plus(21)), '3. tekrar doğru: 21 gün sonra');
r = await review(true);
check(r.stage === 4 && r.mastered_at !== null, '4. doğru tekrar: öğrenildi');
await expectError('öğrenilen kart yeniden tekrar edilmez', () => review(true), 'CARD_NOT_FOUND');
await asUser(A.coach);
await expectError('koç tekrar işaretleyemez', () => db.query(`select public.review_mistake($1, true)`, [card.id]), 'CARD_NOT_FOUND');

console.log('Günlük tekrar hatırlatması');
await asUser(ahmet);
const due = (await one(`insert into public.mistake_cards (student_id, subject_id) values ($1, $2) returning id`, [ahmet, mat])).id;
await db.query(`insert into public.mistake_cards (student_id, subject_id) values ($1, $2)`, [ahmet, mat]);
await asSuper();
await db.query(`update public.mistake_cards set due_on = $1::date where student_id = $2 and mastered_at is null`, [today, ahmet]);
let n = (await one(`select public.send_review_reminders() n`)).n;
const note = await one(`select data from public.notifications where user_id = $1 and kind = 'review'`, [ahmet]);
check(n === 1 && note.data.count === 2 && note.data.route === '/student/mistakes', 'tekrarı gelen 2 kart için tek bildirim', note);
check((await one(`select public.send_review_reminders() n`)).n === 0, 'aynı gün ikinci kez gönderilmez');
await asUser(ahmet);
await expectError('istemci hatırlatma tetikleyemez', () => db.query(`select public.send_review_reminders()`), 'permission denied');

console.log('Veliye haftalık rapor');
await db.query(`insert into public.question_logs (student_id, subject_id, correct, wrong, logged_on)
  values ($1, $2, 40, 10, $3::date), ($1, $2, 30, 0, $4::date), ($1, $2, 99, 0, $5::date)`,
  [ahmet, mat, today, await plus(-3), await plus(-9)]);
await db.query(`insert into public.study_sessions (student_id, started_at, duration_sec) values ($1, now() - interval '1 day', 3000)`, [ahmet]);
await asSuper();
n = (await one(`select public.send_parent_weekly_reports() n`)).n;
const rep = await one(`select data, ref_id from public.notifications where user_id = $1 and kind = 'weekly_report'`, [parent]);
check(n === 1 && rep.data.child === 'Ahmet' && rep.data.questions === 80 && rep.data.minutes === 50,
  'veliye: 80 soru (eski hafta hariç), 50 dk', rep?.data);
check(rep.data.days >= 2 && rep.data.route === `/parent/child/${ahmet}?tab=4` && rep.ref_id === ahmet, 'aktif gün ve rota', rep.data);
check((await one(`select public.send_parent_weekly_reports() n`)).n === 0, 'aynı hafta ikinci kez gönderilmez');
check((await one(`select count(*)::int c from public.notifications where kind = 'weekly_report' and user_id <> $1`, [parent])).c === 0, 'yalnızca velilere gider');

console.log('Silme ve hesap silme');
await asUser(ahmet);
await db.query(`delete from public.mistake_cards where id = $1`, [due]);
ok('öğrenci kartını siler');
await asUser(A.coach);
await db.query(`select public.delete_student_account($1)`, [ahmet]);
await asSuper();
check((await one(`select count(*)::int c from public.mistake_cards where student_id = $1`, [ahmet])).c === 0, 'hesap silinince kartlar da silinir');

console.log('Geri alma ve yeniden uygulama');
const name = '20261018190000_mistakes_and_parent_report';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.mistake_cards') t`)).t === null, 'tablo kalktı');
await expectError('bildirim türleri eski haline döndü', () => db.query(`insert into public.notifications (user_id, kind) values ($1, 'review')`, [can]), 'notifications_kind_check');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select to_regclass('public.mistake_cards') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
