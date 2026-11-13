// Kaynak takibi (20261112100000_book_topic_marks): kitap × konu işaretleri;
// öğrenci ve koçu işaretler, veli yalnızca görür, başka kurum göremez.
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
  await asUser(student);
  const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, `${name} Veli`,
    { guardian_approval: true });
  return { org, admin, coach, student, parent };
}

const A = await school('Bal Akademi', 'ADMINBK1');
const B = await school('Arı Kurs', 'ADMINBK2');
await asSuper();
const mat = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
const topic = (await one(`select id from public.topics where subject_id = $1 order by sort limit 1`, [mat])).id;
const term = (await one(`select public.current_term() t`)).t;


const fiz = (await one(`select id from public.subjects where code = 'TYT_FIZ'`)).id;
const fizTopic = (await one(`select id from public.topics where subject_id = $1 order by sort limit 1`, [fiz])).id;
await asUser(A.admin);
const book = (await one(`insert into public.books (name, publisher, subject_id) values ('345 Allstar', '345', $1) returning id`, [mat])).id;
const mixed = (await one(`insert into public.books (name, publisher) values ('Karma Deneme', 'X') returning id`)).id;
await asUser(A.student);
const sb = (await one(`insert into public.student_books (student_id, book_id) values ($1, $2) returning id`, [A.student, book])).id;
const sbMixed = (await one(`insert into public.student_books (student_id, book_id) values ($1, $2) returning id`, [A.student, mixed])).id;
const marks = async () => (await rows(`select student_book_id, topic_id, marked_by from public.book_topic_marks order by marked_at`));

console.log('İşaretleme');
await db.query(`select public.set_book_topic_mark($1, $2, true)`, [sb, topic]);
await db.query(`select public.set_book_topic_mark($1, $2, true)`, [sb, topic]);
let m = await marks();
check(m.length === 1 && m[0].marked_by === A.student, 'öğrenci işaretler (iki kez basınca tek satır)', m);
await expectError('kitabın dersi dışındaki konu reddedilir', () =>
  db.query(`select public.set_book_topic_mark($1, $2, true)`, [sb, fizTopic]), 'BAD_TOPIC');
await db.query(`select public.set_book_topic_mark($1, $2, true)`, [sbMixed, fizTopic]);
check((await marks()).length === 2, 'karma kitapta her dersin konusu işaretlenir');
await expectError('doğrudan ekleme kapalı', () =>
  db.query(`insert into public.book_topic_marks (student_book_id, topic_id, tenant_id, student_id) select $1, $2, tenant_id, id from public.profiles where id = $3`, [sb, fizTopic, A.student]));
await expectError('doğrudan silme kapalı', () => db.query(`delete from public.book_topic_marks`));

await asUser(A.coach);
check((await marks()).length === 2, 'koç görür');
await db.query(`select public.set_book_topic_mark($1, $2, false)`, [sb, topic]);
check((await marks()).length === 1, 'koç işareti kaldırır');
await db.query(`select public.set_book_topic_mark($1, $2, true)`, [sb, topic]);
await asUser(A.admin);
check((await marks()).length === 2, 'müdür görür');
await asUser(A.parent);
check((await marks()).length === 2, 'veli görür');
await expectError('veli işaretleyemez', () =>
  db.query(`select public.set_book_topic_mark($1, $2, false)`, [sb, topic]), 'NOT_ALLOWED');
await asUser(B.student);
check((await marks()).length === 0, 'başka kurumun öğrencisi göremez');
await expectError('başka kurumun öğrencisi işaretleyemez', () =>
  db.query(`select public.set_book_topic_mark($1, $2, true)`, [sb, topic]), 'NOT_ALLOWED');
await asUser(B.coach);
check((await marks()).length === 0, 'başka kurumun koçu göremez');
await expectError('başka kurumun koçu işaretleyemez', () =>
  db.query(`select public.set_book_topic_mark($1, $2, true)`, [sb, topic]), 'NOT_ALLOWED');
await asSuper();
await db.exec(`set role anon`);
await expectError('anonim okuyamaz', () => db.query(`select * from public.book_topic_marks`));
await expectError('anonim çağıramaz', () => db.query(`select public.set_book_topic_mark($1, $2, true)`, [sb, topic]));

console.log('Silme');
await asUser(A.coach);
await db.query(`delete from public.student_books where id = $1`, [sbMixed]);
await asSuper();
check((await marks()).length === 1, 'kitap listeden silinince işaretleri de silinir');

console.log('Geri alma');
await db.exec(read(rbDir, '20261112100000_book_topic_marks.down.sql'));
check((await one(`select to_regclass('public.book_topic_marks') t`)).t === null, 'tablo kalktı');
await db.exec(read(migDir, '20261112100000_book_topic_marks.sql'));
ok('yeniden uygulandı');

console.log(failures ? `\n${failures} FAIL` : '\nhepsi geçti');
process.exit(failures ? 1 : 0);
