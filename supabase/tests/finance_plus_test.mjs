// Finans eklentileri (20261106100000_finance_plus): hesaplar, indirim, kısmi ödeme, makbuz, iade, gelir, toplu ücret, veli.

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

const A = await school('Bal Akademi', 'ADMINFP1');
const B = await school('Arı Kurs', 'ADMINFP2');
await asUser(A.coach);
const code2 = (await one(`select public.create_invite('student', null, 5) c`)).c;
const s2 = await signUp(code2, 'Bal Akademi Kardeş');
await asUser(A.admin);
await db.query(`select public.set_guardian_phone($1, 'Ayşe Veli', '+905321112233')`, [A.student]);

console.log('Hesaplar');
const kasa = (await one(`insert into public.finance_accounts (name, kind, org_id) values (' Kasa ', 'cash', $1) returning *`, [B.org]));
check(kasa.org_id === A.org && kasa.name === 'Kasa', 'kurum sunucuda yazıldı');
const banka = (await one(`insert into public.finance_accounts (name, kind, iban, opening_balance) values ('Ziraat', 'bank', 'TR12 0001 0000 0000 0000 0000 01', 1000) returning *`)).id;
await expectError('aynı adla ikinci hesap olmaz', () => db.query(`insert into public.finance_accounts (name) values ('kasa')`), 'finance_accounts_name');
await expectError('IBAN biçimi', () => db.query(`insert into public.finance_accounts (name, iban) values ('X', 'TR1')`), 'check');
await asUser(B.admin);
const bKasa = (await one(`insert into public.finance_accounts (name) values ('Kasa') returning id`)).id;
check((await rows(`select id from public.finance_accounts`)).length === 1, 'öteki müdür yalnızca kendi hesabını görür');

console.log('İndirimli ücret');
await asUser(A.admin);
const inst = (n) => JSON.stringify(n.map(([d, a]) => ({ due_on: d, amount: a })));
await expectError('taksit toplamı fiyat − indirim olmalı', () => db.query(
  `select public.create_fee($1, 'YKS', 30000, $2, $3, null, 5, null, null)`,
  [A.student, JSON.stringify([{ kind: 'sibling', amount: 3000 }]), inst([['2026-10-05', 15000], ['2026-11-05', 15000]])]), 'FINANCE_BAD_TOTAL');
const fee = (await one(`select public.create_fee($1, 'YKS', 30000, $2, $3, 'not', 5, 'Ayşe', '+905321112233') id`,
  [A.student, JSON.stringify([{ kind: 'sibling', amount: 3000, note: 'kardeş' }]),
   inst([['2026-10-05', 9000], ['2026-11-05', 9000], ['2026-12-05', 9000]])])).id;
const disc = await rows(`select kind, amount from public.finance_discounts where fee_id = $1`, [fee]);
check(disc.length === 1 && Number(disc[0].amount) === 3000, 'kardeş indirimi kaydedildi', disc);
await expectError('indirim doğrudan yazılamaz', () => db.query(`insert into public.finance_discounts (fee_id, kind, amount, org_id, tenant_id) values ($1, 'other', 1, $2, gen_random_uuid())`, [fee, A.org]), 'permission');
const ids = (await rows(`select id from public.finance_installments where fee_id = $1 order by due_on`, [fee])).map((r) => r.id);

console.log('Kısmi ödeme ve makbuz');
const p1 = (await one(`select public.record_payment($1, 5000, '2026-10-06', 'cash', $2, null) r`, [fee, kasa.id])).r;
const i1 = await one(`select paid_amount, paid_on from public.finance_installments where id = $1`, [ids[0]]);
check(Number(i1.paid_amount) === 5000 && i1.paid_on === null && p1.receipt_no === '2026-000001' && Number(p1.remaining) === 22000,
  'kısmi ödeme: taksit ödenmedi sayılır, makbuz no 2026-000001', { i1, p1 });
const p2 = (await one(`select public.record_payment($1, 13000, '2026-11-02', 'transfer', $2, null) r`, [fee, banka])).r;
check(p2.allocated.length === 2 && Number(p2.allocated[0].amount) === 4000 && p2.receipt_no === '2026-000002',
  'fazlası sonraki taksite dağıtıldı, tek makbuz', p2);
const st = await rows(`select paid_amount, paid_on, method from public.finance_installments where fee_id = $1 order by due_on`, [fee]);
check(st[0].paid_on !== null && st[1].paid_on !== null && st[1].method === 'transfer' && Number(st[2].paid_amount) === 0,
  'iki taksit ödendi', st);
await expectError('kalan borçtan fazlası alınamaz', () =>
  db.query(`select public.record_payment($1, 9001, current_date, 'cash', null, null)`, [fee]), 'FINANCE_OVERPAYMENT');
await expectError('başka kurumun hesabına yazılamaz', () =>
  db.query(`select public.record_payment($1, 10, current_date, 'cash', $2, null)`, [fee, bKasa]), 'FINANCE_BAD_ACCOUNT');
await db.query(`update public.finance_installments set paid_on = null, paid_amount = 0 where id = $1`, [ids[0]]);
check((await one(`select paid_on from public.finance_installments where id = $1`, [ids[0]])).paid_on !== null,
  'ödendi bilgisi doğrudan değiştirilemez');
await expectError('ödenenin altına inilemez', () =>
  db.query(`update public.finance_installments set amount = 100 where id = $1`, [ids[0]]), 'FINANCE_BELOW_PAID');

console.log('Makbuz iptali');
check((await one(`select public.void_receipt($1) n`, [p2.receipt_no])).n === 2, 'makbuzun iki satırı iptal');
const v = await rows(`select paid_amount, paid_on from public.finance_installments where fee_id = $1 order by due_on`, [fee]);
check(Number(v[0].paid_amount) === 5000 && v[0].paid_on === null && Number(v[1].paid_amount) === 0, 'taksitler geri döndü', v);
await expectError('olmayan makbuz', () => db.query(`select public.void_receipt('2026-999999')`), 'FINANCE_RECEIPT_NOT_FOUND');

console.log('Sonradan burs');
await db.query(`select public.add_fee_discount($1, 'scholarship', 10000, 'başarı bursu')`, [fee]);
const after = await rows(`select amount from public.finance_installments where fee_id = $1 order by due_on`, [fee]);
check(after.length === 2 && Number(after[1].amount) === 8000 && Number(after[0].amount) === 9000,
  'son taksit silindi, bir öncekinden 1000 düşüldü', after);
await expectError('kalan borçtan büyük indirim olmaz', () =>
  db.query(`select public.add_fee_discount($1, 'other', 50000, null)`, [fee]), 'FINANCE_DISCOUNT_TOO_BIG');

console.log('Kayıt iptali ve iade');
await expectError('tahsil edilenden fazla iade olmaz', () =>
  db.query(`select public.cancel_fee($1, 6000, current_date, 'cash', $2, null)`, [fee, kasa.id]), 'FINANCE_REFUND_TOO_BIG');
const c = (await one(`select public.cancel_fee($1, 2000, '2026-11-20', 'cash', $2, 'taşındı') r`, [fee, kasa.id])).r;
const cf = await one(`select status, cancelled_on from public.finance_fees where id = $1`, [fee]);
const ci = await rows(`select amount, paid_on from public.finance_installments where fee_id = $1`, [fee]);
check(cf.status === 'cancelled' && ci.length === 1 && Number(ci[0].amount) === 5000 && ci[0].paid_on !== null && c.receipt_no === '2026-000003',
  'iptal: ödenmemiş taksit silindi, kısmi taksit ödenen tutara indi, iade makbuzu', { cf, ci, c });
await expectError('iptal edilen ücrete tahsilat olmaz', () =>
  db.query(`select public.record_payment($1, 10, current_date, 'cash', null, null)`, [fee]), 'FINANCE_CANCELLED');
await expectError('ödemesi olan ücret silinemez', () => db.query(`delete from public.finance_fees where id = $1`, [fee]), 'FINANCE_HAS_PAYMENTS');

console.log('Diğer gelir ve virman');
const r1 = (await one(`select public.record_income('2026-11-21', 'books', 450, 'cash', $1, $2, null, 'deneme seti') r`, [kasa.id, A.student])).r;
check(r1 === '2026-000004', 'gelir makbuzu', r1);
const inc = await one(`select student_name, amount from public.finance_incomes where receipt_no = $1`, [r1]);
check(inc.student_name === 'Bal Akademi Öğrenci', 'gelir öğrenciye bağlandı', inc);
await expectError('gelir doğrudan yazılamaz', () => db.query(`insert into public.finance_incomes (received_on, category, amount, org_id, tenant_id) values (current_date, 'books', 1, $1, gen_random_uuid())`, [A.org]), 'permission');
await db.query(`insert into public.finance_transfers (from_account, to_account, amount, moved_on) values ($1, $2, 1000, current_date)`, [kasa.id, banka]);
await expectError('başka kurumun hesabına virman olmaz', () =>
  db.query(`insert into public.finance_transfers (from_account, to_account, amount, moved_on) values ($1, $2, 1, current_date)`, [kasa.id, bKasa]), 'FINANCE_BAD_ACCOUNT');
await db.query(`insert into public.finance_expenses (spent_on, category, amount, account_id) values (current_date, 'rent', 100, $1)`, [kasa.id]);
await expectError('gider başka kurumun hesabına yazılamaz', () =>
  db.query(`insert into public.finance_expenses (spent_on, category, amount, account_id) values (current_date, 'rent', 100, $1)`, [bKasa]), 'FINANCE_BAD_ACCOUNT');

console.log('Toplu ücret');
await db.query(`insert into public.fee_plans (name, total, installment_count) values ('12. sınıf YKS', 20000, 2)`);
const bulk = (await one(`select public.create_fees_bulk($1, '12. sınıf YKS', 20000, '[]', $2, null, 5) r`,
  [[A.student, s2, B.student], inst([['2026-12-05', 10000], ['2027-01-05', 10000]])])).r;
check(bulk.created === 2 && bulk.skipped.length === 1, 'iki öğrenciye açıldı, başka kurumun öğrencisi atlandı', bulk);
const withPhone = await one(`select payer_name, payer_phone from public.finance_fees where student_id = $1 and title = '12. sınıf YKS'`, [A.student]);
check(withPhone.payer_phone === '+905321112233' && withPhone.payer_name === 'Ayşe Veli', 'veli telefonu yoklama kaydından', withPhone);
const again = (await one(`select public.create_fees_bulk($1, '12. SINIF YKS', 20000, '[]', $2, null, 5) r`,
  [[A.student], inst([['2026-12-05', 20000]])])).r;
check(again.created === 0, 'aynı başlıkta aktif ücreti olan atlanır', again);
const dup = (await one(`select public.create_fees_bulk($1, '12. SINIF YKS', 20000, '[]', $2, null, 5, true) r`,
  [[A.student], inst([['2026-12-05', 20000]])])).r;
check(dup.created === 1 && dup.skipped.length === 0, 'istenirse aynı başlıkta da açılır', dup);
check((await one(`select count(*)::int c from public.finance_fees where student_id = $1 and public.norm_key(title) = public.norm_key('12. sınıf YKS')`, [A.student])).c === 2, 'ikinci ücret açıldı');

console.log('Veli görünümü');
await asUser(A.parent);
const mine = (await one(`select public.my_child_finance($1) r`, [A.student])).r;
const yks = mine.fees.find((f) => f.title === 'YKS');
check(mine.org_name === 'Bal Akademi' && mine.fees.length === 3 && yks.status === 'cancelled'
  && Number(yks.discount) === 13000 && yks.payments.some((p) => p.kind === 'refund'),
  'veli ücretleri, indirimleri ve makbuzları görür', mine);
check(!yks.payments.some((p) => p.receipt_no === p2.receipt_no), 'iptal edilen makbuz görünmez');
check((await rows(`select id from public.finance_payments`)).length === 0, 'veli tabloları doğrudan okuyamaz');
await asUser(B.parent);
await expectError('başkasının çocuğu', () => db.query(`select public.my_child_finance($1)`, [A.student]), 'NOT_ALLOWED');
for (const [who, n] of [[A.coach, 'koç'], [A.student, 'öğrenci']]) {
  await asUser(who);
  const seen = (await rows(`select id from public.finance_payments`)).length
    + (await rows(`select id from public.finance_accounts`)).length
    + (await rows(`select id from public.finance_incomes`)).length;
  check(seen === 0, `${n} finans satırı görmez`, seen);
  await expectError(`${n} tahsilat yazamaz`, () =>
    db.query(`select public.record_payment($1, 1, current_date, 'cash', null, null)`, [fee]), 'FINANCE_NOT_ADMIN');
}

console.log('Hatırlatma kalan tutarı yazar');
await asUser(A.admin);
const pf = (await one(`select id from public.finance_fees where student_id = $1 and title = '12. sınıf YKS'`, [A.student])).id;
const pi = (await one(`select id from public.finance_installments where fee_id = $1 order by due_on limit 1`, [pf])).id;
await db.query(`select public.record_payment($1, 2500, current_date, 'cash', null, null)`, [pf]);
await db.query(`select public.send_payment_reminders($1)`, [[pi]]);
await asSuper();
check((await one(`select body from public.sms_outbox order by created_at desc limit 1`)).body.includes('7.500 TL'), 'SMS kalan tutarla');

console.log('Geri alma ve yeniden uygulama');
const name = '20261106100000_finance_plus';
const later = migs.filter((f) => f > `${name}.sql`).map((f) => f.replace('.sql', '')).reverse();
for (const l of later) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.finance_payments') t`)).t === null, 'tablolar kaldırıldı');
await db.exec(read(migDir, `${name}.sql`));
for (const l of [...later].reverse()) await db.exec(read(migDir, `${l}.sql`));
check((await one(`select count(*)::int c from public.finance_payments`)).c > 0, 'yeniden uygulandı, ödenmiş taksitler tahsilata döndü');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
