// WhatsApp: kurum bağlantısı, kilitli alma, webhook durumu
// (20261111130000_whatsapp).
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
async function signUp(code, name) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true,
      privacy_version: '1.0' })])).id;
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
const A = await school('Bal Akademi', 'ADMINWA1');
const B = await school('Arı Kurs', 'ADMINWA2');
const TOKEN = 'EAAG' + 'x'.repeat(60);

console.log('Bağlantı (müdür)');
await asUser(A.admin);
let st = await one(`select * from public.org_whatsapp_status()`);
check(st.connected === false && st.queued === 0, 'başta bağlı değil', st);
await expectError('ilk bağlantıda anahtar zorunlu', () =>
  db.query(`select public.set_org_whatsapp('1234567890', '9876543210', '+90 532 000 00 00')`), 'WA_TOKEN_REQUIRED');
await expectError('kimlikler yalnızca rakam', () =>
  db.query(`select public.set_org_whatsapp('12ab', '9876543210', null, $1)`, [TOKEN]), 'WA_BAD_ID');
await expectError('kısa anahtar', () =>
  db.query(`select public.set_org_whatsapp('1234567890', '9876543210', null, 'kisa')`), 'WA_BAD_TOKEN');
await expectError('şablon adı küçük harf / rakam / _', () =>
  db.query(`select public.set_org_whatsapp('1234567890', '9876543210', null, $1, 'Kötü Ad')`, [TOKEN]), 'WA_BAD_TEMPLATE');
await db.query(`select public.set_org_whatsapp('1234567890', '9876543210', '+90 532 000 00 00', $1)`, [TOKEN]);
st = await one(`select * from public.org_whatsapp_status()`);
check(st.connected === true && st.phone_number_id === '1234567890' && st.template_name === 'kurum_bilgilendirme',
  'bağlandı', st);
check(!('access_token' in st), 'durum anahtarı döndürmez', Object.keys(st));
await db.query(`select public.set_org_whatsapp('1234567890', '9876543210', '+90 532 111 11 11', null)`);
await asSuper();
check((await one(`select access_token t from public.org_whatsapp where org_id = $1`, [A.org])).t === TOKEN,
  'anahtarsız güncelleme kayıtlı anahtarı korur');

console.log('Yetki');
await asUser(A.admin);
await expectError('müdür tabloyu doğrudan okuyamaz', () => db.query(`select * from public.org_whatsapp`), 'permission denied');
await asUser(A.coach);
await expectError('koç durumu göremez', () => db.query(`select * from public.org_whatsapp_status()`), 'NOT_ALLOWED');
await expectError('koç bağlayamaz', () =>
  db.query(`select public.set_org_whatsapp('1234567890', '9876543210', null, $1)`, [TOKEN]), 'NOT_ALLOWED');
await asUser(A.student);
await expectError('öğrenci claim_messages çağıramaz', () => db.query(`select * from public.claim_messages(5)`), 'permission denied');
await expectError('öğrenci whatsapp_mark çağıramaz', () => db.query(`select public.whatsapp_mark('x', 'read')`), 'permission denied');
await asUser(B.admin);
st = await one(`select * from public.org_whatsapp_status()`);
check(st.connected === false, 'B kurumu A’nın bağlantısını görmez', st);

console.log('Kuyruktan alma');
await asSuper();
for (const [org, tenant, n] of [[A.org, A.tenant, 1], [A.org, A.tenant, 2], [B.org, B.tenant, 3]]) {
  await db.query(
    `insert into public.sms_outbox (tenant_id, org_id, phone, body, created_at)
     values ($1, $2, '+90500000000${n}', 'mesaj ${n}', now() - make_interval(mins => $3))`, [tenant, org, 10 - n]);
}
await db.query(
  `insert into public.sms_outbox (tenant_id, org_id, channel, phone, body) values ($1, $2, 'sms', '+905000000009', 'eski sms')`,
  [A.tenant, A.org]);
check((await one(`select count(*)::int c from public.sms_outbox where channel = 'whatsapp'`)).c === 3,
  'yeni mesajlar varsayılan olarak WhatsApp');
let got = await rows(`select * from public.claim_messages(50)`);
check(got.length === 2 && got[0].body === 'mesaj 1' && got[1].body === 'mesaj 2',
  'yalnızca bağlı kurumun WhatsApp mesajları alınır, eskiden yeniye', got.map((g) => g.body));
check(got[0].org_name === 'Bal Akademi' && got[0].access_token === TOKEN && got[0].default_template === 'kurum_bilgilendirme'
  && got[0].template_lang === 'tr', 'bağlantı bilgisi satırla gelir', got[0]);
check((await rows(`select * from public.claim_messages(50)`)).length === 0, 'ikinci çağrı boş (çift gönderim yok)');
check((await one(`select status from public.sms_outbox where body = 'mesaj 3'`)).status === 'queued',
  'bağlı olmayan kurumun mesajı kuyrukta bekler');
const sms = await rows(`select * from public.claim_sms(50)`);
check(sms.length === 1 && sms[0].body === 'eski sms', 'claim_sms yalnızca SMS kanalını alır', sms);

console.log('Webhook durumu');
await db.query(`update public.sms_outbox set status = 'sent', wa_message_id = 'wamid.A1' where body = 'mesaj 1'`);
await db.query(`update public.sms_outbox set status = 'sent', wa_message_id = 'wamid.A2' where body = 'mesaj 2'`);
check((await one(`select public.whatsapp_mark('wamid.A1', 'read') n`)).n === 1, 'okundu yazıldı');
let m = await one(`select status, delivered_at, read_at from public.sms_outbox where body = 'mesaj 1'`);
check(m.status === 'sent' && m.delivered_at && m.read_at, 'okundu teslimi de doldurur', m);
await db.query(`select public.whatsapp_mark('wamid.A1', 'delivered', null, now() + interval '1 hour')`);
const again = await one(`select read_at, delivered_at from public.sms_outbox where body = 'mesaj 1'`);
check(+again.delivered_at === +m.delivered_at, 'geç gelen teslim bilgisi ezmez');
await db.query(`select public.whatsapp_mark('wamid.A2', 'failed', 'numara WhatsApp kullanmıyor')`);
m = await one(`select status, error from public.sms_outbox where body = 'mesaj 2'`);
check(m.status === 'failed' && m.error.includes('WhatsApp kullanmıyor'), 'hata yazıldı', m);
check((await one(`select public.whatsapp_mark('wamid.yok', 'read') n`)).n === 0, 'bilinmeyen kimlik yok sayılır');
await asUser(A.admin);
st = await one(`select * from public.org_whatsapp_status()`);
check(st.sent === 1 && st.read === 1 && st.delivered === 1 && st.failed === 1, 'müdür sayıları görür', st);

console.log('Bağlantıyı kaldırma');
await db.query(`select public.disconnect_org_whatsapp()`);
check((await one(`select * from public.org_whatsapp_status()`)).connected === false, 'kaldırıldı');
await asSuper();
check((await one(`select count(*)::int c from public.org_whatsapp`)).c === 0, 'anahtar silindi');

console.log('Geri alma ve yeniden uygulama');
await db.exec(read(rbDir, '20261111130000_whatsapp.down.sql'));
check((await one(`select to_regclass('public.org_whatsapp') t`)).t === null, 'tablo kaldırıldı');
check((await one(`select count(*)::int c from information_schema.columns
  where table_name = 'sms_outbox' and column_name = 'channel'`)).c === 0, 'sütunlar kaldırıldı');
check((await rows(`select * from public.claim_sms(50)`)).length >= 1, 'eski claim_sms geri geldi');
await db.exec(read(migDir, '20261111130000_whatsapp.sql'));
check((await one(`select to_regprocedure('public.claim_messages(int)') f`)).f !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
