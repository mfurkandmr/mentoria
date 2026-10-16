// Kurum yazı tipi: varsayılan, müdür değiştirir, geçersiz yazı tipi
// reddedilir, giriş/davet ekranı markası yazı tipini döndürür, yetki,
// dershane izolasyonu ve geri alma.
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
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id, tenant_id`, [name]));
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org.id]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const studentCode = (await one(`select public.create_invite('student', null, 10) c`)).c;
  const student = await signUp(studentCode, `${name} Öğrenci`);
  await asSuper();
  const slug = (await one(`select slug from public.tenants where id = $1`, [org.tenant_id])).slug;
  return { admin, coach, student, tenant: org.tenant_id, slug, studentCode };
}

const A = await school('Bal Akademi', 'ADMINFT1');
const B = await school('Yıldız', 'ADMINFT2');
const font = async (t) => { await asSuper(); return (await one(`select font_family f from public.tenants where id = $1`, [t])).f; };

check(await font(A.tenant) === 'nunito', 'varsayılan yazı tipi nunito (mevcut görünüm değişmez)');

// --- Müdür değiştirir ---
await asUser(A.admin);
await db.query(`select public.update_my_branding('Bal Akademi', '#FFC531', '#6C5CE7', null, 'poppins')`);
check(await font(A.tenant) === 'poppins', 'müdür yazı tipini değiştirir');
await asUser(A.admin);
await db.query(`select public.update_my_branding('Bal Akademi', '#FFC531', '#6C5CE7')`);
check(await font(A.tenant) === 'poppins', 'yazı tipi verilmezse (eski uygulama) değişmez');
await asUser(A.admin);
await db.query(`select public.update_my_branding('Bal Akademi', '#FFC531', '#6C5CE7', null, ' Playfair_Display ')`);
check(await font(A.tenant) === 'playfair_display', 'büyük/küçük harf ve boşluk tolere edilir');
check(await font(B.tenant) === 'nunito', 'başka dershanenin yazı tipi değişmez');

await asUser(A.admin);
await expectError('listede olmayan yazı tipi reddedilir', () =>
  db.query(`select public.update_my_branding('Bal Akademi', '#FFC531', '#6C5CE7', null, 'comic_sans')`), 'INVALID_FONT');
await asUser(A.coach);
await expectError('koç yazı tipini değiştiremez', () =>
  db.query(`select public.update_my_branding('X', '#000000', '#000000', null, 'oswald')`), 'NOT_ALLOWED');
await asUser(A.student);
await expectError('öğrenci yazı tipini değiştiremez', () =>
  db.query(`select public.update_my_branding('X', '#000000', '#000000', null, 'oswald')`), 'NOT_ALLOWED');
await asUser(A.admin);
await expectError('müdür tabloya doğrudan yazamaz', async () => {
  const r = await db.query(`update public.tenants set font_family = 'baloo_2' where id = $1 returning id`, [A.tenant]);
  if (r.rows.length === 0) throw new Error('güncellenmedi');
});
await asSuper();
await expectError('kısıt: geçersiz değer tabloya da yazılamaz', () =>
  db.query(`update public.tenants set font_family = 'wingdings' where id = $1`, [A.tenant]), 'tenants_font_family_check');

// --- Herkes görür ---
await asUser(A.student);
check((await one(`select font_family f from public.tenants where id = $1`, [A.tenant]))?.f === 'playfair_display',
  'öğrenci kendi dershanesinin yazı tipini okur');
await asAnon();
check((await one(`select public.tenant_branding($1) b`, [A.slug])).b?.font_family === 'playfair_display',
  'giriş ekranı markası (slug) yazı tipini döndürür');
await asUser(A.admin);
const invite = (await one(`select public.create_invite('coach') c`)).c;
await asAnon();
check((await one(`select public.check_invite($1) r`, [invite])).r?.tenant?.font_family === 'playfair_display',
  'davet kodu kontrolü yazı tipini döndürür');

// --- Süper admin ---
await asSuper();
const sa = await signUp(A.studentCode, 'Süper Admin');
await asSuper();
await db.query(`insert into public.platform_admins (user_id) values ($1)`, [sa]);
await asUser(sa);
await db.query(`update public.tenants set font_family = 'space_mono' where id = $1`, [B.tenant]);
check(await font(B.tenant) === 'space_mono', 'süper admin dershanenin yazı tipini değiştirir');

// --- Yeni listeye geçiş: listeden çıkan yazı tipi Nunito'ya döner ---
await asSuper();
const v1 = migs.find((f) => f.includes('tenant_fonts.sql'));
const v2 = migs.find((f) => f.includes('tenant_fonts_v2'));
// A iki listede de olan bir yazı tipinde (poppins); B eski listeden birinde.
await db.query(`update public.tenants set font_family = 'poppins' where id = $1`, [A.tenant]);
await db.exec(read(rbDir, v2.replace('.sql', '.down.sql')));
await db.query(`update public.tenants set font_family = 'montserrat' where id = $1`, [B.tenant]);
await db.exec(read(migDir, v2));
check(await font(B.tenant) === 'nunito', 'listeden çıkan yazı tipi (montserrat) Nunito’ya döner');
check(await font(A.tenant) === 'poppins', 'iki listede de olan yazı tipi korunur');
await asUser(A.admin);
await expectError('eski listedeki yazı tipi artık reddedilir', () =>
  db.query(`select public.update_my_branding('Bal Akademi', '#FFC531', '#6C5CE7', null, 'montserrat')`), 'INVALID_FONT');

// --- Geri alma ve yeniden uygulama (yeni → ilk liste → yazı tipi yok) ---
await asSuper();
await db.exec(read(rbDir, v2.replace('.sql', '.down.sql')));
await db.query(`update public.tenants set font_family = 'inter' where id = $1`, [B.tenant]);
ok('v2 geri alındı: ilk listedeki yazı tipi yeniden kullanılabilir');
await db.exec(read(rbDir, v1.replace('.sql', '.down.sql')));
const gone = await one(`select
  (select count(*)::int from information_schema.columns where table_name = 'tenants' and column_name = 'font_family') c,
  (select count(*)::int from pg_proc where proname = 'update_my_branding') f,
  (select pronargs from pg_proc where proname = 'update_my_branding') n`);
check(gone.c === 0 && gone.f === 1 && gone.n === 4, 'geri alma: kolon kalktı, fonksiyon eski haline döndü', gone);
await asUser(A.admin);
await db.query(`select public.update_my_branding('Bal Akademi', '#0EA5E9', '#E5484D')`);
ok('geri alma sonrası müdür markayı kaydedebilir');
await asAnon();
check(!('font_family' in (await one(`select public.tenant_branding($1) b`, [A.slug])).b), 'geri alma: tenant_branding eski haline döndü');
await asSuper();
await db.exec(read(migDir, v1));
await db.exec(read(migDir, v2));
check(await font(A.tenant) === 'nunito', 'yeniden uygulama başarılı (varsayılan nunito)');
await asUser(A.admin);
await db.query(`select public.update_my_branding('Bal Akademi', '#FFC531', '#6C5CE7', null, 'patrick_hand')`);
check(await font(A.tenant) === 'patrick_hand', 'yeniden uygulamadan sonra yeni liste geçerli');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
