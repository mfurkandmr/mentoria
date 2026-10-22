// Davet kodu tahminine karşı önlemler (20261022110000_invite_rate_limit): güvenli kod
// üretimi ve check_invite'ta IP başına / toplam hatalı deneme sınırı.
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

const asSuper = () => db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('request.headers', '', false);`);
const asUser = (id) => db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
// PostgREST istek başlıklarını request.headers ayarına yazar. Canlıda ölçüldüğü gibi:
// cf-connecting-ip ve sb-forwarded-for gerçek IP'dir; x-forwarded-for'a istemcinin
// yazdığı (sahte) değer başa eklenir, gerçek IP sona.
const asAnonWith = (headers) => db.exec(`set role anon; select set_config('request.jwt.claim.sub', '', false);
  select set_config('request.headers', '${JSON.stringify(headers)}', false);`);
let spoof = 0;
const asAnonFrom = (ip) => asAnonWith({
  'cf-connecting-ip': ip, 'sb-forwarded-for': ip, 'x-forwarded-for': `9.9.${spoof++ % 250}.1,${ip}`,
});
const one = async (sql, p = []) => (await db.query(sql, p)).rows[0];
async function expectError(n, fn, pattern) {
  try { await fn(); bad(n, 'hata bekleniyordu'); }
  catch (e) { (!pattern || e.message.includes(pattern)) ? ok(n) : bad(n, e.message); }
}
async function signUp(code, name) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true, privacy_version: '1.0' })])).id;
}
const checkInvite = async (code) => (await one(`select public.check_invite($1) r`, [code])).r;
const ALPHABET = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$/;

await asSuper();
const org = (await one(`insert into public.organizations (name, seat_limit) values ('Bal Akademi', 50) returning id, invite_code`));
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMINRL1', $1, 'admin')`, [org.id]);
const admin = await signUp('ADMINRL1', 'Müdür');
await asUser(admin);
const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Ayşe Koç');
await asUser(coach);
const studentCode = (await one(`select public.create_invite('student', null, 10) c`)).c;

// --- Kod üretimi -----------------------------------------------------------------------
console.log('Kodlar güvenli kaynaktan, aynı biçimde');
check(studentCode.length === 8 && ALPHABET.test(studentCode), 'kişisel davet 8 karakter, aynı alfabe', studentCode);
check(/^MENTORIA-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/.test(org.invite_code), 'kurum kodu MENTORIA-XXXXXX', org.invite_code);
await asUser(admin);
const regenerated = (await one(`select public.regenerate_org_invite_code() c`)).c;
check(/^MENTORIA-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/.test(regenerated) && regenerated !== org.invite_code,
  'yenilenen kurum kodu da aynı biçimde', regenerated);
await asSuper();
const codes = (await db.query(`select public.random_code(8) c from generate_series(1, 500)`)).rows.map((r) => r.c);
check(codes.every((c) => c.length === 8 && ALPHABET.test(c)), '500 kodun hepsi biçime uyar');
check(new Set(codes).size === 500, '500 kod birbirinden farklı');
check(new Set(codes.join('')).size === 32, '32 karakterin hepsi kullanılır');
const src = (await one(`select prosrc from pg_proc where proname = 'random_code'`)).prosrc;
check(src.includes('gen_random_uuid') && !src.includes('random()'), 'random() kullanılmaz');
await asUser(coach);
await expectError('random_code dışarıdan çağrılamaz', () => db.query(`select public.random_code(8)`), 'permission');
await asSuper();
await signUp(studentCode, 'Elif Yılmaz');
ok('yeni kodla kayıt çalışır');

// --- IP başına sınır -----------------------------------------------------------------
console.log('IP başına 10 dakikada 30 hatalı deneme');
let allNull = true;
// Her denemede x-forwarded-for'un başına başka sahte IP yazılır; sınır yine gerçek IP'ye işler.
for (let i = 0; i < 30; i++) {
  await asAnonFrom('1.1.1.1');
  if ((await checkInvite(`YANLIS${i}`)) !== null) allNull = false;
}
check(allNull, '30 hatalı deneme boş döner');
await expectError('31. deneme reddedilir (sahte x-forwarded-for işe yaramaz)', () => checkInvite('YANLIS99'), 'TOO_MANY_ATTEMPTS');
await asSuper();
check((await one(`select count(distinct ip)::int c from public.invite_check_failures`)).c === 1,
  'sahte değerler ayrı IP sayılmaz', (await db.query(`select distinct ip from public.invite_check_failures`)).rows);
await asAnonFrom('1.1.1.1');
await expectError('sınır dolunca doğru kod da beklemek zorunda', () => checkInvite(studentCode), 'TOO_MANY_ATTEMPTS');
await asAnonFrom('2.2.2.2');
check((await checkInvite(studentCode))?.role === 'student', 'başka IP etkilenmez');
check((await checkInvite(org.invite_code)) === null, 'eski kurum kodu artık geçmez (sayılır)');
check((await checkInvite(regenerated.toLowerCase()))?.role === 'student', 'kurum kodu küçük harfle de doğrulanır');
let valid = true;
for (let i = 0; i < 30; i++) if ((await checkInvite(studentCode))?.role !== 'student') valid = false;
check(valid, 'doğru kod sayılmaz (30 doğru deneme)');
await asSuper();
check((await one(`select count(*)::int c from public.invite_check_failures where ip = '2.2.2.2'`)).c === 1,
  'yalnızca hatalı deneme yazılır');
await db.query(`update public.invite_check_failures set at = now() - interval '11 minutes' where ip = '1.1.1.1'`);
await asAnonFrom('1.1.1.1');
check((await checkInvite(studentCode))?.role === 'student', '10 dakika sonra yeniden denenebilir');

// --- Toplam sınır ----------------------------------------------------------------------
console.log('Hangi başlık IP sayılır');
await asAnonWith({ 'sb-forwarded-for': '7.7.7.7', 'x-forwarded-for': '1.2.3.4,7.7.7.7' });
await checkInvite('YOKBOYLE1');
await asAnonWith({ 'x-forwarded-for': '1.2.3.4, 5.6.7.8,8.8.4.4' });
await checkInvite('YOKBOYLE2');
await asSuper();
let ips = (await db.query(`select ip from public.invite_check_failures order by id desc limit 2`)).rows.map((r) => r.ip);
check(ips[1] === '7.7.7.7', 'cf-connecting-ip yoksa sb-forwarded-for', ips);
check(ips[0] === '8.8.4.4', 'ikisi de yoksa x-forwarded-for\'un son değeri', ips);

console.log('Toplamda 10 dakikada 5000 hatalı deneme (acil fren)');
await asSuper();
await db.query(`delete from public.invite_check_failures`);
await db.query(`insert into public.invite_check_failures (ip) select 'gercek-' || g from generate_series(1, 4999) g`);
await asAnonFrom('3.3.3.3');
check((await checkInvite(studentCode))?.role === 'student', '4999 hatalı denemede gerçek kullanıcı etkilenmez');
await asSuper();
await db.query(`insert into public.invite_check_failures (ip) values ('gercek-5000')`);
await asAnonFrom('3.3.3.3');
await expectError('yeni IP de reddedilir', () => checkInvite(studentCode), 'TOO_MANY_ATTEMPTS');
await asSuper();
await db.query(`delete from public.invite_check_failures where ip like 'gercek-%'`);
await asAnonFrom('3.3.3.3');
check((await checkInvite(studentCode))?.role === 'student', 'sayaç boşalınca açılır');

// --- Temizlik ve erişim -------------------------------------------------------------------
console.log('Temizlik ve erişim');
await asSuper();
await db.query(`insert into public.invite_check_failures (ip, at) values ('eski', now() - interval '2 hours')`);
await asAnonFrom('4.4.4.4');
await checkInvite('YOKBOYLE');
await asSuper();
check((await one(`select count(*)::int c from public.invite_check_failures where ip = 'eski'`)).c === 0,
  '1 saatten eski kayıtlar silinir');
await db.exec(`select set_config('request.headers', '', false); set role anon;`);
check((await checkInvite('BASLIKSIZ')) === null, 'başlık yoksa da çalışır');
await asSuper();
check((await one(`select count(*)::int c from public.invite_check_failures where ip = 'unknown'`)).c === 1,
  'başlıksız istek "unknown" sayılır');
await asAnonFrom('5.5.5.5');
await expectError('anon sayacı okuyamaz', () => db.query(`select * from public.invite_check_failures`), 'permission');
await asUser(coach);
await expectError('koç sayacı okuyamaz', () => db.query(`select * from public.invite_check_failures`), 'permission');
await expectError('koç sayacı silemez', () => db.query(`delete from public.invite_check_failures`), 'permission');

// --- Geri alma ---------------------------------------------------------------------------
console.log('Geri alma ve yeniden uygulama');
// Ters sırayla: önce 20261022120000 (güvenilir IP), sonra 20261022110000.
const ipName = '20261022120000_invite_rate_limit_ip';
await asSuper();
await db.query(`delete from public.invite_check_failures`);
await db.exec(read(rbDir, `${ipName}.down.sql`));
for (let i = 0; i < 20; i++) {
  await asAnonFrom('1.1.1.1');
  await checkInvite(`GERI${i}`);
}
await asAnonFrom('1.1.1.1');
check((await checkInvite(studentCode))?.role === 'student',
  'IP geri alınınca eski (taklit edilebilir) anahtar döner: her deneme başka IP');
await asSuper();
await db.query(`delete from public.invite_check_failures`);
const name = '20261022110000_invite_rate_limit';
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.invite_check_failures') t`)).t === null, 'sayaç tablosu kalktı');
check((await one(`select count(*)::int c from pg_proc where proname = 'random_code'`)).c === 0, 'random_code kalktı');
await asUser(coach);
const oldCode = (await one(`select public.create_invite('student', null, 1) c`)).c;
check(oldCode.length === 8 && ALPHABET.test(oldCode), 'eski üretim çalışır');
await asAnonFrom('1.1.1.1');
check((await checkInvite(oldCode))?.role === 'student', 'eski check_invite çalışır');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
await db.exec(read(migDir, `${ipName}.sql`));
await asAnonFrom('6.6.6.6');
check((await checkInvite(oldCode))?.role === 'student', 'yeniden uygulandı');
const def = (await one(`select prosrc from pg_proc where proname = 'check_invite'`)).prosrc;
check(def.includes('cf-connecting-ip') && def.includes('>= 30'), 'güvenilir IP sürümü geri geldi');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
