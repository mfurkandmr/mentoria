// Güvenlik sıkılaştırması (20261109130000_security_tighten): kazanım yardımcıları
// doğrudan çağrılamaz; kullanılan numara denemeleri hız sınırına sayılır.
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
const fromIp = (ip) => db.query(`select set_config('request.headers', $1, false)`, [JSON.stringify({ 'cf-connecting-ip': ip })]);
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
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMINST1', $1, 'admin')`, [org]);
const admin = await signUp('ADMINST1', 'Müdür');
await asUser(admin);
await signUp((await one(`select public.create_invite('coach') c`)).c, 'Ayşe Koç');
const code =`MENTORIA-${org.slice(0, 6).toUpperCase()}`;
await db.query(`update public.organizations set invite_code = $2 where id = $1`, [org, code]);
const student = await signUp(code, 'Elif Yılmaz', { student_number: '1001' });
const outcome = '00000000-0000-0000-0000-000000000001';

console.log('Kazanım yardımcıları doğrudan çağrılamaz');
for (const fn of ['outcome_label', 'outcome_topic']) {
  await asUser(student);
  await expectError(`öğrenci ${fn} çağıramaz`, () => db.query(`select public.${fn}($1)`, [outcome]), 'permission');
  await asUser(admin);
  await expectError(`müdür ${fn} çağıramaz`, () => db.query(`select public.${fn}($1)`, [outcome]), 'permission');
  await asAnon();
  await expectError(`girişsiz ${fn} çağrılamaz`, () => db.query(`select public.${fn}($1)`, [outcome]), 'permission');
  await asSuper();
  await db.query(`select public.${fn}($1)`, [outcome]);
  ok(`sunucu tarafı ${fn} çağırabilir`);
}

const failuresOf = async (ip) => {
  await asSuper();
  const n = (await one(`select count(*)::int n from public.invite_check_failures where ip = $1`, [ip])).n;
  await asAnon();
  return n;
};
const match = async (number) => (await one(`select public.match_student_number($1, $2) r`, [code, number])).r;

console.log('Numara denemeleri hız sınırı');
await asAnon();
await fromIp('1.1.1.1');
check((await match('2002')) === 'ok', 'boş numara: ok');
check((await failuresOf('1.1.1.1')) === 0, 'ok sınıra sayılmaz (okul ağı engellenmez)');
for (let i = 0; i < 100; i++) await match('2002');
check((await failuresOf('1.1.1.1')) === 0, '100 ok denemesi de engellenmez');
check((await match('1001')) === 'taken', 'kullanılan numara: taken');
check((await failuresOf('1.1.1.1')) === 1, 'taken sınıra sayılır');
for (let i = 0; i < 29; i++) await match('1001');
await expectError('30 taken sonrası engellenir', () => match('1001'), 'TOO_MANY_ATTEMPTS');
await fromIp('2.2.2.2');
check((await match('1001')) === 'taken', 'başka IP etkilenmez');

console.log('Liste modunda eşleşmiş numara');
await asSuper();
await db.query(`update public.organizations set student_registration_mode = 'list' where id = $1`, [org]);
await db.query(`insert into public.expected_students (org_id, tenant_id, student_number, full_name, status)
                select o.id, o.tenant_id, v.n, v.a, v.s
                from public.organizations o,
                     (values ('3003', 'Can Kaya', 'matched'), ('4004', 'Ali Ak', 'pending')) v(n, a, s)
                where o.id = $1`, [org]);
await asAnon();
await fromIp('3.3.3.3');
check((await match('4004')) === 'ok', 'listedeki boş numara: ok');
check((await failuresOf('3.3.3.3')) === 0, 'listedeki ok sayılmaz');
check((await match('3003')) === 'taken', 'eşleşmiş numara: taken');
check((await failuresOf('3.3.3.3')) === 1, 'eşleşmiş taken sayılır');

console.log('Geri alma ve yeniden uygulama');
const name = '20261109130000_security_tighten';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
await asUser(student);
await db.query(`select public.outcome_label($1)`, [outcome]);
ok('geri alınınca eski izin döner');
await asAnon();
await fromIp('4.4.4.4');
check((await match('1001')) === 'taken', 'eski davranış: taken');
check((await failuresOf('4.4.4.4')) === 0, 'geri alınınca taken sayılmaz');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
await asUser(student);
await expectError('yeniden uygulandı', () => db.query(`select public.outcome_label($1)`, [outcome]), 'permission');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
