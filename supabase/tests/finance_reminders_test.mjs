// Taksit günü bildirimi ve veliye SMS hatırlatması
// (20261105110000_finance_reminders).
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
const rows = async (sql, p = []) => (await db.query(sql, p)).rows;
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
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const sCode = (await one(`select public.create_invite('student', null, 5) c`)).c;
  const student = await signUp(sCode, `${name} Öğrenci`);
  await asUser(student);
  const parent = await signUp((await one(`select public.create_invite('parent') c`)).c, `${name} Veli`,
    { guardian_approval: true });
  return { org, admin, coach, student, parent };
}

const A = await school('Bal Akademi', 'ADMINRA1');
const B = await school('Arı Kurs', 'ADMINRB1');
await asSuper();
const today = (await one(`select (now() at time zone 'Europe/Istanbul')::date::text d`)).d;

console.log('Ödeme günü ve veli telefonu');
await asUser(A.admin);
const fee = await one(`insert into public.finance_fees (student_id, title, total, due_day, payer_name, payer_phone)
  values ($1, 'YKS kursu', 25000.5, 10, '  Ayşe Yılmaz ', '+905321234567') returning *`, [A.student]);
check(fee.due_day === 10 && fee.payer_name === 'Ayşe Yılmaz', 'ödeme günü ve veli adı kaydedildi', fee);
await expectError('telefon biçimi denetlenir', () =>
  db.query(`update public.finance_fees set payer_phone = '0532 123 45 67' where id = $1`, [fee.id]), 'check');
await expectError('ödeme günü 1-28', () =>
  db.query(`update public.finance_fees set due_day = 31 where id = $1`, [fee.id]), 'check');
const [due, paid, later] = (await rows(`insert into public.finance_installments (fee_id, due_on, amount)
  values ($1, $2, 12500.5), ($1, $2, 1000), ($1, $2::date + 30, 12500) returning id`, [fee.id, today])).map((r) => r.id);
await db.query(`select public.record_payment($1, 1000, $2, 'cash', null, null, $3)`, [fee.id, today, paid]);
const noPhone = await one(`insert into public.finance_fees (student_id, title, total) values ($1, 'Kitap', 500) returning id`, [A.student]);
const noPhoneInst = (await one(`insert into public.finance_installments (fee_id, due_on, amount) values ($1, $2, 500) returning id`,
  [noPhone.id, today])).id;

console.log('Günü gelen taksit bildirimi');
await asSuper();
check((await one(`select public.notify_due_installments() n`)).n === 1, 'müdüre tek bildirim');
const note = await one(`select data from public.notifications where user_id = $1 and kind = 'installment_due'`, [A.admin]);
check(note.data.count === 2 && note.data.no_phone === 1 && note.data.route === `/admin/finance?remind=${today}`,
  'bildirimde sayı, telefonsuz sayısı ve yol var', note.data);
check(Number(note.data.total) === 13000.5, 'toplam tutar', note.data.total);
check((await one(`select public.notify_due_installments() n`)).n === 0, 'aynı taksit için tekrar bildirim yok');
check((await one(`select count(*)::int c from public.notifications where kind = 'installment_due' and user_id <> $1`, [A.admin])).c === 0,
  'koça, veliye, öteki kuruma bildirim yok');

console.log('SMS hatırlatması');
await asUser(A.admin);
let res = (await one(`select public.send_payment_reminders($1) r`, [[due, paid, noPhoneInst]])).r;
check(res.queued === 1 && res.no_phone === 1 && res.skipped === 1, 'ödenmemiş ve telefonu olana sıraya alındı', res);
const sms = await one(`select phone, body, status from public.sms_outbox`);
check(sms.phone === '+905321234567' && sms.status === 'queued'
  && sms.body === `Sayın Ayşe Yılmaz, Bal Akademi: Bal Akademi Öğrenci için ${today.split('-').reverse().join('.')} vadeli 12.500,50 TL taksit ödemesini hatırlatırız.`,
  'SMS metni', sms.body);
res = (await one(`select public.send_payment_reminders($1) r`, [[due]])).r;
check(res.queued === 0 && res.skipped === 1, 'aynı taksite 20 saat içinde ikinci SMS yok', res);
res = (await one(`select public.send_payment_reminders($1) r`, [[later]])).r;
check(res.queued === 1, 'vadesi gelmemiş taksit de elle hatırlatılabilir', res);
await expectError('müdür SMS kuyruğuna doğrudan yazamaz', () =>
  db.query(`insert into public.sms_outbox (tenant_id, org_id, phone, body) values (gen_random_uuid(), $1, '+905000000000', 'x')`, [A.org]),
  'permission');

await asUser(B.admin);
await expectError('öteki müdür bu kurumun taksitini hatırlatamaz', () =>
  db.query(`select public.send_payment_reminders($1)`, [[due]]), 'FINANCE_NOT_ADMIN');
check((await rows(`select id from public.sms_outbox`)).length === 0, 'öteki müdür SMS kuyruğunu görmez');
for (const [who, n] of [[A.coach, 'koç'], [A.student, 'öğrenci'], [A.parent, 'veli']]) {
  await asUser(who);
  check((await rows(`select id from public.sms_outbox`)).length === 0, `${n} SMS kuyruğunu görmez`);
  await expectError(`${n} hatırlatma gönderemez`, () =>
    db.query(`select public.send_payment_reminders($1)`, [[due]]), 'FINANCE_NOT_ADMIN');
}

console.log('Tutar biçimi ve eski kayıt temizliği');
await asSuper();
const tl = await one(`select public.format_tl(12500) a, public.format_tl(99.5) b, public.format_tl(1234567.05) c`);
check(tl.a === '12.500 TL' && tl.b === '99,50 TL' && tl.c === '1.234.567,05 TL', 'format_tl', tl);
await db.query(`update public.sms_outbox set created_at = now() - interval '91 days'`);
await db.query(`select public.notify_due_installments()`);
check((await one(`select count(*)::int c from public.sms_outbox`)).c === 0, '90 günden eski SMS kayıtları silinir');

console.log('Geri alma ve yeniden uygulama');
const name = '20261105110000_finance_reminders';
// Üstüne kurulan finance_plus önce geri alınır.
const laterDeps = ['20261106100000_finance_plus', '20261106150000_bulk_fee_duplicates'].filter((n) => migs.includes(`${n}.sql`));
for (const l of [...laterDeps].reverse()) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.sms_outbox') t`)).t === null, 'SMS kuyruğu kaldırıldı');
check((await one(`select count(*)::int c from information_schema.columns where table_name = 'finance_fees' and column_name = 'payer_phone'`)).c === 0,
  'veli telefonu sütunu kaldırıldı');
await db.exec(read(migDir, `${name}.sql`));
for (const l of laterDeps) await db.exec(read(migDir, `${l}.sql`));
check((await one(`select to_regclass('public.sms_outbox') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
