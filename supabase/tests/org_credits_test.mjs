// Kurum kredisi ve kurum kodu (20261020100000_org_credits): kod biçimi ve
// benzersizliği, öğrenci eklenince kredi düşer, 0'da hata, harcanan kredi
// geri gelmez, kurum koduyla kayıt, kodu yalnızca müdür görür; geri alma.
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';

const root = process.argv[2] ?? '../..';
const migDir = `${root}/supabase/migrations`;
const rbDir = `${root}/supabase/rollbacks`;
const migs = fs.readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort();
const read = (d, f) => fs.readFileSync(`${d}/${f}`, 'utf8');

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
ok(`${migs.length} migration`);

const asSuper = () => db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
const asUser = (id) => db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
const one = async (sql, p = []) => (await db.query(sql, p)).rows[0];
async function signUp(code, name) {
  await asSuper();
  return (await one(
    `insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true })],
  )).id;
}
async function expectError(n, fn, pattern) {
  try { await fn(); bad(n, 'hata bekleniyordu'); }
  catch (e) { (!pattern || e.message.includes(pattern)) ? ok(n) : bad(n, e.message); }
}
const credits = async (org) => {
  await asSuper();
  return (await one(`select credit_balance c from public.organizations where id = $1`, [org])).c;
};

console.log('Kurum açılışı');
await asSuper();
const org = (await one(`insert into public.organizations (name, seat_limit) values ('Bal Kurs', 3) returning id, invite_code`));
check(/^MENTORIA-[A-Z0-9]{6}$/.test(org.invite_code), 'kod MENTORIA-XXXXXX biçiminde', org.invite_code);
check(await credits(org.id) === 3, 'kredi verilmezse seat_limit kadar başlar');
const given = await one(`insert into public.organizations (name, seat_limit, credit_balance) values ('Kredili', 3, 10) returning credit_balance c`);
check(given.c === 10, 'açıkça verilen kredi korunur');
const codes = (await db.query(`select public.generate_org_invite_code() c from generate_series(1, 300)`)).rows.map((r) => r.c);
check(codes.every((c) => /^MENTORIA-[A-Z0-9]{6}$/.test(c)), '300 kodun hepsi biçime uyar');
check(new Set(codes).size === codes.length, '300 kod birbirinden farklı');

await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMIN001', $1, 'admin')`, [org.id]);
const admin = await signUp('ADMIN001', 'Bal Müdür');
await asUser(admin);
const coach1 = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Birinci Koç');
await asUser(admin);
const coach2 = await signUp((await one(`select public.create_invite('coach') c`)).c, 'İkinci Koç');
check(await credits(org.id) === 3, 'müdür ve koç kayıtları kredi harcamaz');

console.log('Kredi düşer, 0\'da hata');
await asUser(coach1);
const s1 = await signUp((await one(`select public.create_invite('student') c`)).c, 'Elif Öğrenci');
check(await credits(org.id) === 2, 'öğrenci eklenince kredi 1 azalır');

console.log('Kurum koduyla kayıt');
await asUser(admin);
check((await one(`select public.my_org_invite_code() c`)).c === org.invite_code, 'müdür kurum kodunu görür');
await asUser(coach1);
check((await one(`select public.my_org_invite_code() c`)).c === null, 'koç kurum kodunu görmez');
await expectError('kod tablo üzerinden okunamaz',
  () => db.query(`select invite_code from public.organizations`), 'permission denied');
check((await one(`select name from public.organizations`)).name === 'Bal Kurs', 'diğer sütunlar okunur');
check((await one(`select public.my_org_credits() c`)).c.credit_balance === 2, 'koç kalan krediyi görür');
await asUser(admin);
await expectError('müdür krediyi değiştiremez',
  () => db.query(`update public.organizations set credit_balance = 999`), 'permission denied');
await expectError('müdür kredi yükleyemez',
  () => db.query(`select public.add_org_credits($1, 5)`, [org.id]), 'NOT_ALLOWED');

await asSuper();
await db.exec(`set role anon`);
const info = (await one(`select public.check_invite($1) i`, [org.invite_code.toLowerCase()])).i;
check(info?.role === 'student' && info.org_name === 'Bal Kurs' && info.no_credits === false,
  'kurum kodu doğrulanır (küçük harfle de)', info);
check((await one(`select public.check_invite('MENTORIA-XXXXXX') i`)).i === null, 'olmayan kod boş döner');
const s2 = await signUp(org.invite_code, 'Can Öğrenci');
const link = await one(`select coach_id from public.coach_students where student_id = $1`, [s2]);
check(link?.coach_id === coach2, 'kurum koduyla gelen öğrenci en boş koça bağlanır', link);
check(await credits(org.id) === 1, 'kurum koduyla kayıt da kredi harcar');
const s3 = await signUp(org.invite_code, 'Deniz Öğrenci');
check(await credits(org.id) === 0, 'kredi sıfırlandı');
await expectError('kredi 0 iken kurum koduyla kayıt reddedilir', () => signUp(org.invite_code, 'Ece Öğrenci'), 'NO_CREDITS');
await asUser(coach1);
await expectError('kredi 0 iken öğrenci daveti üretilmez',
  () => db.query(`select public.create_invite('student')`), 'NO_CREDITS');
await asSuper();
check((await one(`select public.check_invite($1) i`, [org.invite_code])).i.no_credits === true, 'kayıt ekranı krediyi bilir');
await expectError('kredi 0 iken öğrenci profili doğrudan da eklenemez', async () => {
  await db.exec(`alter table auth.users disable trigger user`);
  const u = (await one(`insert into auth.users (email) values ('d@x.com') returning id`)).id;
  await db.exec(`alter table auth.users enable trigger user`);
  await db.query(`insert into public.profiles (id, full_name, role, org_id) values ($1, 'Doğrudan', 'student', $2)`, [u, org.id]);
}, 'NO_CREDITS');

console.log('Harcanan kredi geri gelmez; yükleme');
await db.query(`delete from public.profiles where id = $1`, [s3]);
check(await credits(org.id) === 0, 'öğrenci silinince kredi geri gelmez');
await db.query(`insert into public.platform_admins (user_id) values ($1)`, [admin]);
await asUser(admin);
check((await one(`select public.add_org_credits($1, 5) c`, [org.id])).c === 5, 'platform yöneticisi kredi yükler');
await asSuper();
await db.query(`delete from public.platform_admins where user_id = $1`, [admin]);

console.log('Kod yenileme ve kapalı kurum');
await asUser(admin);
const fresh = (await one(`select public.regenerate_org_invite_code() c`)).c;
check(fresh !== org.invite_code && /^MENTORIA-/.test(fresh), 'müdür kodu yeniler');
await asUser(coach1);
await expectError('koç kodu yenileyemez', () => db.query(`select public.regenerate_org_invite_code()`), 'NOT_ALLOWED');
await expectError('eski kod artık geçmez', () => signUp(org.invite_code, 'Eski Kod'), 'INVITE_INVALID');
await asSuper();
await db.query(`update public.organizations set is_active = false where id = $1`, [org.id]);
check((await one(`select public.check_invite($1) i`, [fresh])).i === null, 'kapalı kurumun kodu doğrulanmaz');
await expectError('kapalı kuruma kayıt olmaz', () => signUp(fresh, 'Kapalı'), 'ORG_INACTIVE');
await db.query(`update public.organizations set is_active = true where id = $1`, [org.id]);

console.log('Koçsuz kurum');
const empty = await one(`insert into public.organizations (name, seat_limit) values ('Koçsuz', 5) returning invite_code`);
await expectError('koçu olmayan kurumun koduyla kayıt olmaz', () => signUp(empty.invite_code, 'Yalnız'), 'NO_COACH');

console.log('Geri alma ve yeniden uygulama');
const name = '20261020100000_org_credits';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
check(!(await one(`select 1 x from information_schema.columns where table_name = 'organizations' and column_name = 'credit_balance'`)), 'sütunlar kalktı');
await asUser(coach1);
check((await one(`select name from public.organizations`)).name === 'Bal Kurs', 'okuma izni geri geldi');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
check(/^MENTORIA-/.test((await one(`select invite_code from public.organizations where id = $1`, [org.id])).invite_code), 'yeniden uygulanınca kod üretilir');
check(await credits(org.id) === 1, 'kredi kalan koltuktan hesaplanır (3 koltuk, 2 öğrenci)', await credits(org.id));
void s1;

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
