// Öğrencinin sınıf seviyesi (20261111150000_grade_level): kayıtta yazılır,
// öğrenci / koçu değiştirir, başkası değiştiremez; geri alma.
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
async function signUp(code, name, extra = {}) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true,
      privacy_version: '1.0', ...extra })])).id;
}
const invite = async (as, role) => { await asUser(as); return (await one(`select public.create_invite($1) c`, [role])).c; };

await asSuper();
const org = (await one(`insert into public.organizations (name, seat_limit) values ('Bal', 20) returning id`)).id;
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMGRD01', $1, 'admin')`, [org]);
const admin = await signUp('ADMGRD01', 'Bal Müdür', { grade_level: 10 });
const coach = await signUp(await invite(admin, 'coach'), 'Bal Koç');
const coach2 = await signUp(await invite(admin, 'coach'), 'Bal İkinci Koç');
const s9 = await signUp(await invite(coach, 'student'), 'Dokuz Ali', { grade_level: 9 });
const sBad = await signUp(await invite(coach, 'student'), 'Yanlış Can', { grade_level: 'on' });
const s13 = await signUp(await invite(coach, 'student'), 'Fazla Can', { grade_level: 13 });
const sOld = await signUp(await invite(coach, 'student'), 'Eski Ayşe');
await asSuper();
const g = async (id) => (await one(`select grade_level g from public.profiles where id = $1`, [id])).g;

console.log('Kayıt');
check(await g(s9) === 9, '9. sınıf yazıldı');
check(await g(sBad) === null, 'geçersiz değer boş', await g(sBad));
check(await g(s13) === null, 'aralık dışı boş');
check(await g(sOld) === null, 'seçmeyen eski istemci boş');
check(await g(admin) === null, 'öğrenci olmayana yazılmaz');

console.log('Değiştirme');
await asUser(s9);
await db.query(`select public.set_grade_level($1, 10)`, [s9]);
await asSuper();
check(await g(s9) === 10, 'öğrenci kendi sınıfını değiştirir');
await asUser(coach);
await db.query(`select public.set_grade_level($1, 12)`, [sOld]);
await asSuper();
check(await g(sOld) === 12, 'koç öğrencisinin sınıfını değiştirir');
await asUser(admin);
await db.query(`select public.set_grade_level($1, 11)`, [sOld]);
await asSuper();
check(await g(sOld) === 11, 'müdür değiştirir');
await asUser(coach2);
await expectError('başka koç değiştiremez', () => db.query(`select public.set_grade_level($1, 9)`, [sOld]), 'NOT_ALLOWED');
await asUser(s9);
await expectError('öğrenci başkasınınkini değiştiremez', () => db.query(`select public.set_grade_level($1, 9)`, [sOld]), 'NOT_ALLOWED');
await expectError('9-12 dışı reddedilir', () => db.query(`select public.set_grade_level($1, 8)`, [s9]), 'BAD_GRADE');
await asUser(coach);
await expectError('öğrenci olmayan reddedilir', () => db.query(`select public.set_grade_level($1, 9)`, [admin]), 'NOT_ALLOWED');
await expectError('doğrudan güncelleme kapalı', () => db.query(`update public.profiles set grade_level = 9 where id = $1`, [s9]));
await asUser(s9);
check((await one(`select grade_level from public.profiles where id = $1`, [s9])).grade_level === 10, 'öğrenci kendi seviyesini okur');
await asSuper();
await db.exec(`set role anon`);
await expectError('anonim çağıramaz', () => db.query(`select public.set_grade_level($1, 9)`, [s9]));

console.log('Geri alma');
await asSuper();
await db.exec(read(rbDir, '20261111150000_grade_level.down.sql'));
const col = await one(`select count(*)::int n from information_schema.columns where table_name = 'profiles' and column_name = 'grade_level'`);
check(col.n === 0, 'sütun kalktı');
const s2 = await signUp(await invite(coach, 'student'), 'Sonra Gelen', { grade_level: 9 });
check(!!s2, 'eski kayıt fonksiyonu çalışıyor');
await db.exec(read(migDir, '20261111150000_grade_level.sql'));
ok('yeniden uygulandı');

console.log(failures ? `\n${failures} FAIL` : '\nhepsi geçti');
process.exit(failures ? 1 : 0);
