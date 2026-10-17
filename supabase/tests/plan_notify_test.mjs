// Haftalık plan bildirimi: hafta başına tek bildirim (30 dk), geçmiş hafta
// yok, koç ve müdür; geri alma.
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




const A = await school('Bal Akademi', 'ADMINPN1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');

const day = async (k) => { await asSuper(); return (await one(`select (((now() at time zone 'Europe/Istanbul')::date) + $1::int)::text d`, [k])).d; };
const weekOf = async (d) => (await one(`select ($1::date - (extract(isodow from $1::date)::int - 1))::text w`, [d])).w;
const add = (student, d) => db.query(
  `insert into public.plan_items (student_id, day, subject_code, topic) values ($1, $2::date, 'TYT_MAT', 'Problemler')`, [student, d]);
const notes = async (who) => { await asSuper(); return (await db.query(`select data from public.notifications where user_id = $1 and kind = 'plan' order by created_at`, [who])).rows; };

console.log('Plan bildirimi');
const d0 = await day(0), d1 = await day(1), d7 = await day(7), dPast = await day(-7);
await asUser(A.coach);
await add(ahmet, d0);
await add(ahmet, d1);
await add(ahmet, d0);
let n = await notes(ahmet);
const w0 = await weekOf(d0);
// d1 bazen gelecek haftaya düşer (bugün pazar ise); o zaman iki bildirim olur.
const expected = (await weekOf(d1)) === w0 ? 1 : 2;
check(n.length === expected, 'aynı hafta için maddeler tek bildirim', n);
check(n[0].data.week === w0 && n[0].data.from === 'Bal Akademi Koç' && n[0].data.route === '/student/plan', 'bildirimde hafta, koç adı, rota', n[0].data);
await asUser(A.coach);
await add(ahmet, d7);
n = await notes(ahmet);
check(n.length === expected + 1 && n.at(-1).data.week === await weekOf(d7), 'yeni hafta ayrı bildirim', n.map((x) => x.data.week));
await asUser(A.coach);
await add(can, dPast).catch(() => {});
check((await notes(can)).length === 0, 'geçmiş haftaya madde bildirim üretmez');
await asSuper();
await db.query(`update public.notifications set created_at = now() - interval '31 minutes' where user_id = $1 and kind = 'plan'`, [ahmet]);
await asUser(A.coach);
await add(ahmet, d0);
check((await notes(ahmet)).length === expected + 2, '30 dakika sonra yeni ekleme yeniden bildirir');
await asUser(A.admin);
await add(can, d0);
const c = await notes(can);
check(c.length === 1 && c[0].data.from === 'Bal Akademi Müdür', 'müdürün eklediği plan da bildirilir', c);

console.log('Geri alma ve yeniden uygulama');
const name = '20261018250000_plan_notifications';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
await asUser(A.coach);
await add(ahmet, d1);
await asSuper();
check((await one(`select count(*)::int c from public.notifications where kind = 'plan'`)).c === 0, 'geri alınınca bildirim yok');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select count(*)::int c from pg_trigger where tgname = 'notify_plan_item'`)).c === 1, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
