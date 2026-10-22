// KVKK yardımcıları (20261022100000_revoke_consent_helpers): is_minor, has_consent ve
// ranking_visible doğrudan çağrılamaz; onları kullanan RPC'ler çalışmaya devam eder.
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

await asSuper();
const org = (await one(`insert into public.organizations (name, seat_limit) values ('Bal Akademi', 20) returning id`)).id;
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMINCH1', $1, 'admin')`, [org]);
const admin = await signUp('ADMINCH1', 'Müdür');
await asUser(admin);
const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Ayşe Koç');
await asUser(coach);
const code = (await one(`select public.create_invite('student', null, 10) c`)).c;
const thisYear = new Date().getFullYear();
const elif = await signUp(code, 'Elif Yılmaz', { birth_year: 2000, consents: { ranking: true } });
const can = await signUp(code, 'Can Kaya', { birth_year: thisYear - 16, consents: { ranking: true } });

// --- Doğrudan çağrı kapalı -----------------------------------------------------------
console.log('Yardımcılar doğrudan çağrılamaz');
const calls = [
  ['is_minor', `select public.is_minor($1)`, [can]],
  ['has_consent', `select public.has_consent($1, 'ranking')`, [can]],
  ['ranking_visible', `select public.ranking_visible($1)`, [can]],
];
for (const [name, sql, p] of calls) {
  await asUser(elif);
  await expectError(`öğrenci ${name} çağıramaz`, () => db.query(sql, p), 'permission');
  await asUser(coach);
  await expectError(`koç ${name} çağıramaz`, () => db.query(sql, p), 'permission');
  await asAnon();
  await expectError(`girişsiz ${name} çağrılamaz`, () => db.query(sql, p), 'permission');
}

// --- Onları kullanan RPC'ler çalışır ---------------------------------------------------
console.log('RPC\'ler çalışmaya devam eder');
await asUser(can);
let st = (await one(`select public.consent_status() s`)).s;
check(st.minor === true && st.ranking === true && st.ranking_visible === false, 'öğrenci kendi durumunu görür', st);
await asUser(coach);
st = (await one(`select public.consent_status($1) s`, [elif])).s;
check(st.minor === false && st.ranking_visible === true, 'koç öğrencisinin durumunu görür', st);
await asUser(elif);
await db.query(`select public.set_consent('parent_view', true, '1.0')`);
ok('set_consent çalışır');
check(typeof (await one(`select public.create_invite('parent') c`)).c === 'string', 'create_invite çalışır');
const rows = (await db.query(`select * from public.avatar_leaderboard(50, 0)`)).rows;
check(rows.length >= 1, 'avatar_leaderboard çalışır', rows.length);
await asSuper();
check((await one(`select public.is_minor($1) m`, [can])).m === true, 'sunucu tarafı (postgres) çağırabilir');

// --- Geri alma ---------------------------------------------------------------------------
console.log('Geri alma ve yeniden uygulama');
const name = '20261022100000_revoke_consent_helpers';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
await asUser(elif);
check((await one(`select public.is_minor($1) m`, [can])).m === true, 'geri alınınca eski izin döner');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
await asUser(elif);
await expectError('yeniden uygulandı', () => db.query(`select public.is_minor($1)`, [can]), 'permission');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
