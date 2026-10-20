// Kayıt, e-posta doğrulanınca tamamlanır: doğrulanmamış kayıt daveti ve
// öğrenci koltuğunu harcamaz, geçersiz davet kayıt anında reddedilir,
// doğrulamada profil ve koç ilişkisi yazılır; geri alma / yeniden uygulama.
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
const meta = (code, name) => JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true });
async function signUp(code, name, confirmed = true) {
  await asSuper();
  return (await one(
    `insert into auth.users (email, raw_user_meta_data, email_confirmed_at) values ($1, $2, $3) returning id`,
    [`${Math.random()}@x.com`, meta(code, name), confirmed ? new Date().toISOString() : null],
  )).id;
}
const confirm = async (id) => {
  await asSuper();
  await db.query(`update auth.users set email_confirmed_at = now() where id = $1`, [id]);
};
async function expectError(n, fn, pattern) {
  try { await fn(); bad(n, 'hata bekleniyordu'); }
  catch (e) { (!pattern || e.message.includes(pattern)) ? ok(n) : bad(n, e.message); }
}
const profileOf = async (id) => {
  await asSuper();
  return one(`select p.role, p.full_name, p.kvkk_consent_at is not null kvkk,
                (select count(*)::int from public.coach_students where student_id = p.id) coached
              from public.profiles p where p.id = $1`, [id]);
};
const usedCount = async (code) => {
  await asSuper();
  return (await one(`select used_count from public.invite_codes where code = $1`, [code])).used_count;
};

// Kurum: 1 koltuk, tek kullanımlık öğrenci daveti.
await asSuper();
const org = (await one(`insert into public.organizations (name, seat_limit) values ('Bal Kurs', 1) returning id`)).id;
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMIN001', $1, 'admin')`, [org]);
const admin = await signUp('ADMIN001', 'Bal Müdür');
await asUser(admin);
const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Bal Koç');
await asUser(coach);
const studentCode = (await one(`select public.create_invite('student') c`)).c;

console.log('Doğrulanmamış kayıt');
const fake = await signUp(studentCode, 'Sahte Adres', false);
check(!(await profileOf(fake)), 'doğrulanmadan profil oluşmaz');
check((await usedCount(studentCode)) === 0, 'davet harcanmaz');

await expectError('geçersiz davet kayıt anında reddedilir',
  () => signUp('YOKBOYLE1', 'Kimse Yok', false), 'INVITE_INVALID');
await expectError('ad soyad yine zorunlu',
  () => signUp(studentCode, 'A', false), 'NAME_REQUIRED');

console.log('Asıl öğrenci doğru adresle kaydolup doğrular');
const real = await signUp(studentCode, 'Elif Yılmaz', false);
await confirm(real);
const p = await profileOf(real);
check(p?.role === 'student' && p.full_name === 'Elif Yılmaz' && p.kvkk && p.coached === 1,
  'doğrulayınca profil + koç ilişkisi yazılır', p);
check((await usedCount(studentCode)) === 1, 'davet şimdi kullanılmış sayılır');

console.log('Sahte adres sonradan doğrulanmaya çalışılırsa');
await expectError('kullanılmış davetle doğrulama reddedilir',
  () => confirm(fake), 'INVITE_INVALID');
check(!(await profileOf(fake)), 'profil yine yok');

console.log('Tekrar doğrulama / başka güncellemeler');
await asSuper();
await db.query(`update auth.users set email_confirmed_at = now() + interval '1 minute' where id = $1`, [real]);
await db.query(`update auth.users set email = 'yeni@x.com' where id = $1`, [real]);
check((await usedCount(studentCode)) === 1, 'tekrar güncelleme daveti yeniden harcamaz');

console.log('Kredi doğrulama anında da denetlenir');
await asSuper();
await db.query(`update public.organizations set credit_balance = 1 where id = $1`, [org]);
await asUser(coach);
const code2 = (await one(`select public.create_invite('student') c`)).c;
await asSuper();
await db.query(`update public.organizations set credit_balance = 0 where id = $1`, [org]);
await expectError('kredi bitmişken kayıt anında reddedilir',
  () => signUp(code2, 'Zeynep Arslan', false), 'NO_CREDITS');

console.log('Panelden / onaysız modda doğrulanmış eklenen kullanıcı');
await asSuper();
await db.query(`update public.organizations set credit_balance = 5 where id = $1`, [org]);
const instant = await signUp(code2, 'Zeynep Arslan', true);
check((await profileOf(instant))?.role === 'student', 'hemen profil oluşur');

console.log('Fonksiyon dışarıdan çağrılamaz');
await asUser(admin);
await expectError('authenticated apply_signup_invite çağıramaz',
  () => db.query(`select public.apply_signup_invite($1, '{}'::jsonb, true)`, [admin]), 'permission denied');

console.log('Geri alma ve yeniden uygulama');
const name = '20261018160000_signup_after_email_confirm';
await asSuper();
// Eski sürümler koltuk sayar (kredi sonraki migration'da geldi).
await db.query(`update public.organizations set seat_limit = 100 where id = $1`, [org]);
await db.exec(read(rbDir, `${name}.down.sql`));
check(!(await one(`select 1 x from pg_proc where proname = 'apply_signup_invite'`)), 'yardımcı fonksiyon kalktı');
await asUser(coach);
const code3 = (await one(`select public.create_invite('student') c`)).c;
const old = await signUp(code3, 'Eski Davranış', false);
check((await profileOf(old))?.role === 'student', 'eski davranış: eklenince profil oluşur');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
await asUser(coach);
const code4 = (await one(`select public.create_invite('student') c`)).c;
const again = await signUp(code4, 'Yeniden Uygulandı', false);
check(!(await profileOf(again)), 'yeniden uygulanınca doğrulama beklenir');
await confirm(again);
check((await profileOf(again))?.role === 'student', 've doğrulayınca oluşur');

console.log(failures ? `\n${failures} test başarısız` : '\nTüm testler geçti');
process.exit(failures ? 1 : 0);
