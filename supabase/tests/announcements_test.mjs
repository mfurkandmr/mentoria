// Toplu duyuru: müdür kurum geneline, koç kendi öğrencilerine/velilerine;
// alıcı listesi, yetki, sınırlar, my_announcements ve geri alma.
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
async function coachIn(admin, name) {
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, name);
  await asUser(coach);
  return { id: coach, code: (await one(`select public.create_invite('student', null, 10) c`)).c };
}
async function parentOf(student, name) {
  await asUser(student);
  return signUp((await one(`select public.create_invite('parent') c`)).c, name);
}
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  return { org, admin: await signUp(code, `${name} Müdür`) };
}

const A = await school('Bal Akademi', 'ADMINAN1');
const ayse = await coachIn(A.admin, 'Ayşe Koç');
const mehmet = await coachIn(A.admin, 'Mehmet Koç');
const elif = await signUp(ayse.code, 'Elif Yılmaz');
const can = await signUp(ayse.code, 'Can Kaya');
const zeynep = await signUp(mehmet.code, 'Zeynep Arslan');
const elifVeli = await parentOf(elif, 'Elif Veli');
const zeynepVeli = await parentOf(zeynep, 'Zeynep Veli');

const B = await school('Yıldız', 'ADMINAN2');
const bCoach = await coachIn(B.admin, 'Yıldız Koç');
const bStudent = await signUp(bCoach.code, 'Yıldız Öğrenci');

const send = (aud, t = 'Deneme günü', b = 'Cumartesi 10.00 TYT denemesi var.') =>
  db.query(`select public.send_announcement($1, $2, $3) n`, [aud, t, b]).then((r) => r.rows[0].n);
const got = async (kind = 'announcement') => {
  await asSuper();
  return (await db.query(`select user_id, data, ref_id from public.notifications where kind = $1`, [kind])).rows;
};
const ids = (rows) => new Set(rows.map((r) => r.user_id));
const reset = async () => { await asSuper(); await db.exec(`delete from public.notifications where kind = 'announcement'; delete from public.announcements;`); };

console.log('Müdür');
await asUser(A.admin);
check(await send('everyone') === 7, 'herkes: 3 öğrenci + 2 koç + 2 veli', null);
let r = await got();
let s = ids(r);
check(s.size === 7 && !s.has(A.admin) && !s.has(bStudent) && !s.has(B.admin), 'kendisi ve başka kurum alıcı değil', [...s]);
const el = r.find((x) => x.user_id === elif);
check(el.data.title === 'Deneme günü' && el.data.body.startsWith('Cumartesi') && el.data.from === 'Bal Akademi Müdür'
  && el.data.route === '/student/announcements', 'öğrenci bildirimi: başlık, metin, gönderen, rota', el.data);
check(r.find((x) => x.user_id === elifVeli).data.route === '/parent/announcements'
  && r.find((x) => x.user_id === ayse.id).data.route === '/coach/announcements', 'veli ve koç rotaları');
await reset();
await asUser(A.admin);
check(await send('students') === 3 && ids(await got()).has(zeynep), 'öğrenciler: kurumdaki 3 öğrenci');
await reset();
await asUser(A.admin);
check(await send('parents') === 2, 'veliler: 2 veli');
s = ids(await got());
check(s.has(elifVeli) && s.has(zeynepVeli) && s.size === 2, 'yalnızca veliler', [...s]);
await reset();
await asUser(A.admin);
check(await send('coaches') === 2, 'koçlar: 2 koç');
await expectError('müdür "my_students" kullanamaz', () => send('my_students'), 'NOT_ALLOWED');

console.log('Koç');
await reset();
await asUser(ayse.id);
check(await send('my_students') === 2, 'kendi 2 öğrencisi');
s = ids(await got());
check(s.has(elif) && s.has(can) && !s.has(zeynep), 'başka koçun öğrencisi almaz', [...s]);
await reset();
await asUser(ayse.id);
check(await send('my_parents') === 1, 'kendi öğrencilerinin velileri');
s = ids(await got());
check(s.has(elifVeli) && !s.has(zeynepVeli), 'başka koçun velisi almaz', [...s]);
await asUser(ayse.id);
await expectError('koç kurum geneline gönderemez', () => send('everyone'), 'NOT_ALLOWED');
await asUser(bCoach.id);
await asSuper();
await db.query(`delete from public.coach_students where coach_id = $1`, [bCoach.id]);
await asUser(bCoach.id);
await expectError('öğrencisi olmayan koç: alıcı yok', () => send('my_students'), 'ANNOUNCE_NO_RECIPIENTS');

console.log('Yetki ve sınırlar');
await asUser(elif);
await expectError('öğrenci gönderemez', () => send('everyone'), 'NOT_ALLOWED');
await asUser(elifVeli);
await expectError('veli gönderemez', () => send('parents'), 'NOT_ALLOWED');
await asUser(A.admin);
await expectError('boş metin', () => send('students', 'Başlık', '   '), 'ANNOUNCE_INVALID');
await expectError('uzun başlık', () => send('students', 'x'.repeat(81)), 'ANNOUNCE_INVALID');
await expectError('bilinmeyen kitle', () => send('aliens'), 'NOT_ALLOWED');
await reset();
await asUser(A.admin);
for (let i = 0; i < 10; i++) await send('coaches', `Duyuru ${i}`);
await expectError('24 saatte en fazla 10', () => send('coaches'), 'ANNOUNCE_LIMIT');
await expectError('tabloya doğrudan yazılamaz', () => db.query(
  `insert into public.announcements (tenant_id, org_id, audience, title, body) select tenant_id, org_id, 'everyone', 'xx', 'yy' from public.profiles where id = $1`, [A.admin]));
await expectError('bildirim doğrudan yazılamaz', () => db.query(
  `insert into public.notifications (user_id, kind, data) values ($1, 'announcement', '{}')`, [elif]));

console.log('my_announcements');
await reset();
await asUser(A.admin);
await send('everyone', 'Kurum duyurusu');
await asUser(ayse.id);
await send('my_students', 'Koç duyurusu');
const list = async (who) => { await asUser(who); return (await db.query(`select * from public.my_announcements()`)).rows; };
let l = await list(elif);
check(l.length === 2 && l.every((x) => !x.sent_by_me && x.recipients === null), 'öğrenci: iki duyuru, alıcı sayısı gizli', l);
l = await list(zeynep);
check(l.length === 1 && l[0].title === 'Kurum duyurusu' && l[0].sender_name === 'Bal Akademi Müdür', 'diğer koçun öğrencisi yalnızca kurum duyurusunu görür', l);
l = await list(ayse.id);
const kd = l.find((x) => x.title === 'Koç duyurusu');
check(l.length === 2 && kd.sent_by_me && kd.recipients === 2, 'koç: gelen + gönderdiği (alıcı sayısıyla)', l);
l = await list(A.admin);
check(l.length === 2 && l.every((x) => x.recipients !== null), 'müdür kurumdaki tüm gönderilenleri görür', l);
l = await list(mehmet.id);
check(l.length === 1, 'diğer koç kendisine gelmeyen koç duyurusunu görmez', l);
l = await list(B.admin);
check(l.length === 0, 'başka kurum hiçbirini görmez', l);
await asUser(elif);
check((await db.query(`select * from public.announcements`)).rows.length === 0, 'tabloyu öğrenci doğrudan okuyamaz');
await asUser(B.admin);
check((await db.query(`select * from public.announcements`)).rows.length === 0, 'başka kurumun müdürü okuyamaz');

console.log('Geri alma ve yeniden uygulama');
const name = '20261019100000_announcements';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select count(*)::int c from public.notifications where kind = 'announcement'`)).c === 0, 'geri alınınca duyuru bildirimi yok');
check((await one(`select to_regclass('public.announcements') t`)).t === null, 'tablo kaldırıldı');
await db.exec(read(migDir, `${name}.sql`));
await asUser(A.admin);
check(await send('coaches') === 2, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
