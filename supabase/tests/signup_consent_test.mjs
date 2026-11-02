// Kayıtta KVKK onayı zorunlu, metin sürümü değişince yeniden onay
// (20261102100000_signup_consent_required).
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


const raw = async (code, name, meta) => {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, ...meta })])).id;
};
const status = async (id) => { await asUser(id); return (await one(`select public.consent_status() s`)).s; };
const rows = async (id, kind) => {
  await asSuper();
  return (await one(`select count(*)::int c from public.consents where user_id = $1 and kind = $2`, [id, kind])).c;
};

await asSuper();
const org = (await one(`insert into public.organizations (name, seat_limit) values ('Bal Akademi', 20) returning id`)).id;
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMINSC1', $1, 'admin')`, [org]);
const admin = await signUp('ADMINSC1', 'Müdür');
await asUser(admin);
const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Ayşe Koç');
await asUser(coach);
const code = (await one(`select public.create_invite('student', null, 10) c`)).c;

console.log('Kayıtta onay zorunlu');
await expectError('onay yoksa kayıt reddedilir', () => raw(code, 'Onaysız Öğrenci', {}), 'KVKK_REQUIRED');
await expectError('onay false ise reddedilir', () => raw(code, 'Hayır Diyen', { kvkk_consent: false }), 'KVKK_REQUIRED');
await expectError('onay metinle gelirse reddedilir', () => raw(code, 'Metin Onay', { kvkk_consent: 'evet' }), 'KVKK_REQUIRED');
await asSuper();
check((await one(`select count(*)::int c from public.profiles where full_name in ('Onaysız Öğrenci', 'Hayır Diyen')`)).c === 0,
  'onaysız profil açılmadı');
check((await one(`select used_count from public.invite_codes where code = $1`, [code])).used_count === 0,
  'davet hakkı harcanmadı');
// E-posta doğrulanmadan önce: profil yok, doğrulanınca da onay yoksa açılmaz.
await expectError('doğrulama bekleyen onaysız kayıt da reddedilir', async () => {
  await asSuper();
  await db.query(`insert into auth.users (email, raw_user_meta_data, email_confirmed_at) values ($1, $2, null)`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: 'Bekleyen Öğrenci' })]);
}, 'KVKK_REQUIRED');

const elif = await signUp(code, 'Elif Yılmaz', { birth_year: 2000 });
let st = await status(elif);
check(st.privacy_notice === true && st.privacy_version === '1.0', 'onaylanan sürüm okunur', st);

console.log('Metin güncellenince yeniden onay');
await asUser(elif);
await db.query(`select public.set_consent('privacy_notice', true, '1.2')`);
st = await status(elif);
check(st.privacy_version === '1.2', 'yeni sürüm kaydedildi', st.privacy_version);
check((await rows(elif, 'privacy_notice')) === 2, 'eski onay da geçmişte duruyor');
await asUser(elif);
await db.query(`select public.set_consent('privacy_notice', true, '1.2')`);
check((await rows(elif, 'privacy_notice')) === 2, 'aynı sürüm tekrar yazılmaz');
await asUser(elif);
await db.query(`select public.set_consent('ranking', true, '1.2')`);
await asUser(elif);
await db.query(`select public.set_consent('ranking', true, '1.2')`);
check((await rows(elif, 'ranking')) === 1, 'sıralama rızası da aynı sürümle tekrar yazılmaz');
await asUser(elif);
await db.query(`select public.set_consent('privacy_notice', false, '1.2')`);
st = await status(elif);
check(st.privacy_notice === false && st.privacy_version === null, 'geri çekilince sürüm boş', st);

console.log('Her rol kendi durumunu okur');
for (const [who, n] of [[coach, 'koç'], [admin, 'müdür']]) {
  st = await status(who);
  check(st.privacy_version === '1.0', `${n} kendi sürümünü okur`, st);
}
await asUser(coach);
await expectError('başka kurumdaki kişiyi okuyamaz', async () => {
  await asSuper();
  const org2 = (await one(`insert into public.organizations (name, seat_limit) values ('Öteki', 5) returning id`)).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMINSC2', $1, 'admin')`, [org2]);
  const other = await signUp('ADMINSC2', 'Öteki Müdür');
  await asUser(coach);
  await db.query(`select public.consent_status($1)`, [other]);
}, 'NOT_ALLOWED');

console.log('Geri alma ve yeniden uygulama');
const name = '20261102100000_signup_consent_required';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
const loose = await raw(code, 'Eski Kural', {});
await asSuper();
check((await one(`select count(*)::int c from public.profiles where id = $1`, [loose])).c === 1, 'geri alınınca onaysız kayıt eski gibi açılır');
st = await status(elif);
check(st.privacy_version === undefined, 'eski consent_status sürüm döndürmez');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
await expectError('yeniden uygulandı', () => raw(code, 'Yine Onaysız', {}), 'KVKK_REQUIRED');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
