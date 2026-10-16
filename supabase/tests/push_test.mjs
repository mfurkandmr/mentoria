// Telefon bildirimleri: cihaz adresi kaydı, sahiplik, dershane izolasyonu,
// bildirim tetikleyicisinin kayıtları asla engellememesi ve geri alma.
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
  return { admin, coach, code: (await one(`select public.create_invite('student', null, 10) c`)).c };
}

const A = await school('Bal Akademi', 'ADMINPS1');
const elif = await signUp(A.code, 'Elif Yılmaz');
const can = await signUp(A.code, 'Can Kaya');
const B = await school('Yıldız', 'ADMINPS2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');
const TOKEN = 'fcm-token-' + 'x'.repeat(40);

await asUser(elif);
await db.query(`select public.register_device_token($1, 'android')`, [TOKEN]);
const mine = await one(`select user_id, platform, tenant_id is not null t from public.device_tokens`);
check(mine?.user_id === elif && mine.platform === 'android' && mine.t, 'öğrenci kendi cihaz adresini kaydeder (dershaneyle)', mine);
await db.query(`select public.register_device_token($1, 'android')`, [TOKEN]);
check((await one(`select count(*)::int c from public.device_tokens`)).c === 1, 'aynı adres ikinci kez kaydedilmez');
await expectError('geçersiz platform reddedilir', () => db.query(`select public.register_device_token($1, 'tv')`, [TOKEN + 'y']), 'INVALID_PLATFORM');
await expectError('kısa/bozuk adres reddedilir', () => db.query(`select public.register_device_token('abc', 'ios')`));
await expectError('doğrudan tabloya yazılamaz', () => db.query(`insert into public.device_tokens (token, user_id, platform) values ($1, $2, 'ios')`, ['z'.repeat(30), elif]));

await asUser(can);
check((await one(`select count(*)::int c from public.device_tokens`)).c === 0, 'başkasının cihaz adresi görünmez');
await db.query(`select public.unregister_device_token($1)`, [TOKEN]);
await asSuper();
check((await one(`select count(*)::int c from public.device_tokens`)).c === 1, 'başkası adresi silemez');

// Aynı telefonda başka hesapla giriş: adres yeni kullanıcıya geçer.
await asUser(can);
await db.query(`select public.register_device_token($1, 'android')`, [TOKEN]);
await asSuper();
check((await one(`select user_id from public.device_tokens where token = $1`, [TOKEN])).user_id === can, 'aynı cihazda yeni hesap: adres yeni kullanıcıya geçer');

// En fazla 10 cihaz
await asUser(elif);
for (let i = 0; i < 12; i++) await db.query(`select public.register_device_token($1, 'ios')`, [`tok-${i}-` + 'a'.repeat(30)]);
check((await one(`select count(*)::int c from public.device_tokens`)).c === 10, 'kullanıcı başına en fazla 10 cihaz');

// Dershane izolasyonu
await asUser(zeynep);
check((await one(`select count(*)::int c from public.device_tokens`)).c === 0, 'başka dershane hiçbir adresi görmez');
await asAnon();
await expectError('giriş yapmayan kaydedemez', () => db.query(`select public.register_device_token($1, 'web')`, ['w'.repeat(30)]));

// Bildirim tetikleyicisi: Vault/pg_net yokken bile kayıt engellenmez
await asUser(A.coach);
await db.query(`insert into public.tasks (coach_id, student_id, title) values ($1, $2, 'Push testi')`, [A.coach, elif]);
await asUser(elif);
check((await one(`select count(*)::int c from public.notifications where kind = 'task'`)).c === 1, 'push ayarı yokken bildirim kaydı yine oluşur');

// Çıkış: kendi adresini siler
await db.query(`select public.unregister_device_token($1)`, ['tok-11-' + 'a'.repeat(30)]);
check((await one(`select count(*)::int c from public.device_tokens`)).c === 9, 'çıkışta kendi adresini siler');

// Hesap silinince adresler de silinir (öğrenciyi koçu siler)
await asUser(A.coach);
await db.query(`select public.delete_student_account($1)`, [elif]);
await asSuper();
check((await one(`select count(*)::int c from public.device_tokens where user_id = $1`, [elif])).c === 0, 'hesap silinince cihaz adresleri silinir');

// Geri alma ve yeniden uygulama
const pushMigs = migs.filter((f) => f.includes('push_'));
for (const f of [...pushMigs].reverse()) await db.exec(read(rbDir, f.replace('.sql', '.down.sql')));
const gone = await one(`select to_regclass('public.device_tokens') t,
  (select count(*)::int from pg_trigger where tgname = 'push_on_notification') g`);
check(gone.t === null && gone.g === 0, 'geri alma: tablo ve tetikleyici kaldırıldı', gone);
await asUser(A.coach);
await db.query(`insert into public.tasks (coach_id, student_id, title) values ($1, $2, 'Geri alma sonrası')`, [A.coach, can]);
ok('geri alma sonrası görev/bildirim akışı çalışır');
await asSuper();
for (const f of pushMigs) await db.exec(read(migDir, f));
check((await one(`select to_regclass('public.device_tokens') t`)).t !== null, 'yeniden uygulama başarılı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
