// Kurum müdürünün kendi markasını yönetmesi: ad/renk/logo, kurum adı eşitleme,
// yetki ve dershane sınırları, geri alma.
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
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id, tenant_id`, [name]));
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org.id]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const student = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, `${name} Öğrenci`);
  return { org: org.id, tenant: org.tenant_id, admin, coach, student };
}

const A = await school('Mentoria Test Kurumu', 'ADMINBR1');
const B = await school('Yıldız Dershanesi', 'ADMINBR2');
const base = `https://proje.supabase.co/storage/v1/object/public/tenant-logos`;

// Müdür kendi markasını günceller
await asUser(A.admin);
await db.query(`select public.update_my_branding('Bal Akademi', '#0ea5e9', '#e5484d', $1)`, [`${base}/${A.tenant}/logo-1.png`]);
await asSuper();
const t = await one(`select name, primary_color, secondary_color, logo_url, slug, is_active from public.tenants where id = $1`, [A.tenant]);
check(t.name === 'Bal Akademi' && t.primary_color === '#0EA5E9' && t.logo_url.endsWith('/logo-1.png'), 'müdür ad, renk ve logoyu günceller', t);
check(t.slug === 'mentoria-test-kurumu' && t.is_active, 'slug ve aktiflik değişmez');
check((await one(`select name from public.organizations where id = $1`, [A.org])).name === 'Bal Akademi', 'tek kurumlu dershanede kurum adı da değişir');

// Koç ve öğrenci yeni adı görür
for (const [who, id] of [['öğrenci', A.student], ['koç', A.coach]]) {
  await asUser(id);
  const seen = await one(`select name, logo_url from public.tenants`);
  check(seen?.name === 'Bal Akademi' && seen.logo_url, `${who} yeni adı ve logoyu görür`, seen);
}

// Yetki ve sınırlar
await asUser(A.coach);
await expectError('koç markayı değiştiremez', () => db.query(`select public.update_my_branding('X', '#000000', '#000000')`), 'NOT_ALLOWED');
await asUser(A.student);
await expectError('öğrenci markayı değiştiremez', () => db.query(`select public.update_my_branding('X', '#000000', '#000000')`), 'NOT_ALLOWED');
await asUser(A.admin);
await expectError('başka dershanenin klasöründeki logo reddedilir', () => db.query(`select public.update_my_branding('Bal Akademi', '#0EA5E9', '#E5484D', $1)`, [`${base}/${B.tenant}/x.png`]), 'LOGO_NOT_ALLOWED');
await expectError('dış adres logo olarak reddedilir', () => db.query(`select public.update_my_branding('Bal Akademi', '#0EA5E9', '#E5484D', 'https://kotu.site/logo.png')`), 'LOGO_NOT_ALLOWED');
await expectError('geçersiz renk reddedilir', () => db.query(`select public.update_my_branding('Bal Akademi', 'mavi', '#E5484D')`));
await expectError('boş ad reddedilir', () => db.query(`select public.update_my_branding(' ', '#0EA5E9', '#E5484D')`), 'NAME_REQUIRED');
await asSuper();
check((await one(`select name from public.tenants where id = $1`, [B.tenant])).name === 'Yıldız Dershanesi', 'başka dershane etkilenmez');

// Kurum kartından ad değişince marka adı da değişir
await asUser(A.admin);
await db.query(`update public.organizations set name = 'Bal Akademi İzmir' where id = $1`, [A.org]);
await asUser(A.student);
check((await one(`select name from public.tenants`)).name === 'Bal Akademi İzmir', 'kurum adı değişince öğrenci yeni adı görür');

// Birden çok kurumlu dershanede şube adı markayı değiştirmez
await asSuper();
await db.query(`insert into public.organizations (name, tenant_id) values ('Bal Akademi Şube 2', $1)`, [A.tenant]);
await asUser(A.admin);
await db.query(`update public.organizations set name = 'Merkez Şube' where id = $1`, [A.org]);
await asSuper();
check((await one(`select name from public.tenants where id = $1`, [A.tenant])).name === 'Bal Akademi İzmir', 'çok kurumlu dershanede şube adı markayı değiştirmez');

// Geri alma ve yeniden uygulama
// admin_branding'den sonraki migration'lar (ör. tenant_fonts) aynı fonksiyonu
// değiştirdiği için önce onlar, ters sırayla geri alınır.
const mig = migs.find((f) => f.includes('admin_branding'));
const later = migs.filter((f) => f > mig && read(migDir, f).includes('update_my_branding'));
for (const f of [...later].reverse()) await db.exec(read(rbDir, f.replace('.sql', '.down.sql')));
await db.exec(read(rbDir, mig.replace('.sql', '.down.sql')));
const gone = await one(`select (select count(*)::int from pg_proc where proname = 'update_my_branding') f,
  (select count(*)::int from pg_trigger where tgname = 'sync_tenant_name') t`);
check(gone.f === 0 && gone.t === 0, 'geri alma: fonksiyon ve tetikleyici kaldırıldı', gone);
await asUser(A.admin);
await db.query(`update public.organizations set name = 'Merkez' where id = $1`, [A.org]);
ok('geri alma sonrası kurum adı değiştirme çalışır');
await asSuper();
await db.exec(read(migDir, mig));
for (const f of later) await db.exec(read(migDir, f));
check((await one(`select count(*)::int c from pg_proc where proname = 'update_my_branding'`)).c === 1, 'yeniden uygulama başarılı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
