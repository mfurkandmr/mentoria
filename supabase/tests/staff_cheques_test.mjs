// Personel ve çek / senet (20261109150000_staff_cheques): yalnızca kurum müdürü;
// tahsil edilen çek ücrete / gelire, ödenen çek gidere işlenir ve geri alınabilir.
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
async function signUp(code, name) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true,
      privacy_version: '1.0', guardian_approval: true })])).id;
}
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const student = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, `${name} Öğrenci`);
  await asUser(admin);
  const teacher = (await one(`insert into public.teachers (full_name, branches) values ($1, '{Matematik}') returning id`,
    [`${name} Öğretmen`])).id;
  return { org, admin, coach, student, teacher };
}

const A = await school('Bal Akademi', 'ADMINSC1');
const B = await school('Arı Kurs', 'ADMINSC2');
const today = new Date().toISOString().slice(0, 10);

console.log('Personel kartı');
await asUser(A.admin);
const sec = await one(`insert into public.staff_members (full_name, job, phone, monthly_salary, org_id, note)
  values ('  Hale Yurt  ', 'secretary', '+905550001122', 25000, $1, '  ') returning *`, [B.org]);
check(sec.org_id === A.org && sec.full_name === 'Hale Yurt' && sec.note === null, 'kurum sunucudan, ad ve not temiz', sec);
const linked = await one(`insert into public.staff_members (full_name, job, teacher_id) values ('Öğretmen Kartı', 'teacher', $1) returning id`, [A.teacher]);
check(!!linked.id, 'öğretmene bağlı kart');
await expectError('başka kurumun öğretmeni bağlanamaz',
  () => db.query(`insert into public.staff_members (full_name, teacher_id) values ('X', $1)`, [B.teacher]), 'STAFF_BAD_REF');
await expectError('başka kurumun koçu bağlanamaz',
  () => db.query(`insert into public.staff_members (full_name, profile_id) values ('X', $1)`, [B.coach]), 'STAFF_BAD_REF');
await expectError('öğrenci personele bağlanamaz',
  () => db.query(`insert into public.staff_members (full_name, profile_id) values ('X', $1)`, [A.student]), 'STAFF_BAD_REF');
await expectError('aynı öğretmene iki kart açılmaz',
  () => db.query(`insert into public.staff_members (full_name, teacher_id) values ('X', $1)`, [A.teacher]), 'unique');
await expectError('geçersiz telefon reddedilir',
  () => db.query(`update public.staff_members set phone = '123' where id = $1`, [sec.id]), 'check');
await db.query(`update public.staff_members set org_id = $1 where id = $2`, [B.org, sec.id]);
check((await one(`select org_id from public.staff_members where id = $1`, [sec.id])).org_id === A.org, 'kurum sonradan değişmez');

console.log('İzin');
const leave = await one(`insert into public.staff_leaves (staff_id, kind, start_on, end_on, org_id, note)
  values ($1, 'annual', '2026-12-01', '2026-12-05', $2, ' Yıllık ') returning *`, [sec.id, B.org]);
check(leave.org_id === A.org && leave.note === 'Yıllık', 'izin kuruma bağlandı', leave);
await expectError('çakışan izin reddedilir',
  () => db.query(`insert into public.staff_leaves (staff_id, start_on, end_on) values ($1, '2026-12-05', '2026-12-07')`, [sec.id]), 'STAFF_LEAVE_OVERLAP');
await db.query(`insert into public.staff_leaves (staff_id, start_on, end_on) values ($1, '2026-12-06', '2026-12-07')`, [sec.id]);
ok('bitişik izin kabul edilir');
await expectError('bitişi başından önce izin reddedilir',
  () => db.query(`insert into public.staff_leaves (staff_id, start_on, end_on) values ($1, '2026-12-20', '2026-12-10')`, [sec.id]), 'check');

console.log('Personel ödemesi');
const exp = await one(`insert into public.finance_expenses (spent_on, category, amount, staff_id, staff_name)
  values (current_date, 'salary', 25000, $1, 'sahte') returning *`, [sec.id]);
check(exp.staff_name === 'Hale Yurt', 'ad sunucudan', exp);
await expectError('gider iki kişiye bağlanamaz',
  () => db.query(`insert into public.finance_expenses (spent_on, category, amount, staff_id, teacher_id) values (current_date, 'salary', 1, $1, $2)`, [sec.id, A.teacher]), 'finance_expenses_one_payee');

console.log('Yetki');
await asUser(B.admin);
for (const t of ['staff_members', 'staff_leaves', 'finance_cheques']) {
  check((await rows(`select id from public.${t}`)).length === 0, `öteki müdür ${t} görmez`);
}
await expectError('başka kurumun personeline izin yazılamaz',
  () => db.query(`insert into public.staff_leaves (staff_id, start_on, end_on) values ($1, '2027-01-01', '2027-01-02')`, [sec.id]), 'FINANCE_NOT_ADMIN');
await asUser(A.coach);
check((await rows(`select id from public.staff_members`)).length === 0, 'koç personeli görmez');
await expectError('koç personel ekleyemez',
  () => db.query(`insert into public.staff_members (full_name) values ('X')`), 'FINANCE_NOT_ADMIN');
await asUser(A.student);
check((await rows(`select id from public.finance_cheques`)).length === 0, 'öğrenci çek görmez');
await expectError('öğrenci çek ekleyemez',
  () => db.query(`insert into public.finance_cheques (direction, party_name, amount, due_on) values ('received', 'X', 5, current_date)`), 'FINANCE_NOT_ADMIN');
await asAnon();
await expectError('anonim okuyamaz', () => db.query(`select * from public.staff_members`), 'permission');
await expectError('anonim çek okuyamaz', () => db.query(`select * from public.finance_cheques`), 'permission');

console.log('Alınan çek: gelire işlenir');
await asUser(A.admin);
const acc = (await one(`insert into public.finance_accounts (name) values ('Banka') returning id`)).id;
const c1 = await one(`insert into public.finance_cheques (direction, serial_no, bank, party_name, student_id, amount, due_on, status, receipt_no)
  values ('received', ' 12345 ', ' Ziraat ', ' Hasan Yılmaz ', $1, 7000, current_date, 'collected', 'sahte') returning *`, [A.student]);
check(c1.status === 'portfolio' && c1.receipt_no === null && c1.student_name === 'Bal Akademi Öğrenci' && c1.serial_no === '12345',
  'ilk durum ve ad sunucudan', c1);
await expectError('doğrudan güncelleme kapalı',
  () => db.query(`update public.finance_cheques set status = 'collected' where id = $1`, [c1.id]), 'permission');
await expectError('geçersiz geçiş reddedilir',
  () => db.query(`select public.set_cheque_status($1, 'paid')`, [c1.id]), 'CHEQUE_BAD_STATUS');
await expectError('ciro için kişi gerekir',
  () => db.query(`select public.set_cheque_status($1, 'endorsed')`, [c1.id]), 'CHEQUE_NEEDS_ENDORSEE');
let s = (await one(`select * from public.set_cheque_status($1, 'deposited', $2, $3)`, [c1.id, today, acc]));
check(s.status === 'deposited' && s.account_id === acc, 'tahsile verildi', s);
check((await rows(`select id from public.finance_incomes`)).length === 0, 'tahsile verilince gelir yazılmaz');
s = (await one(`select * from public.set_cheque_status($1, 'collected', $2, $3)`, [c1.id, today, acc]));
check(s.status === 'collected' && !!s.receipt_no, 'tahsil edildi, makbuz var', s);
const inc = await one(`select amount, account_id, voided_at, student_id from public.finance_incomes where receipt_no = $1`, [s.receipt_no]);
check(Number(inc.amount) === 7000 && inc.account_id === acc && inc.voided_at === null && inc.student_id === A.student, 'gelir yazıldı', inc);
await expectError('tahsil edilen silinemez',
  () => db.query(`delete from public.finance_cheques where id = $1`, [c1.id]), 'CHEQUE_NOT_DELETABLE');
const rcpt = s.receipt_no;
s = (await one(`select * from public.set_cheque_status($1, 'bounced', $2)`, [c1.id, today]));
check(s.status === 'bounced' && s.receipt_no === null, 'karşılıksız', s);
check((await one(`select voided_at from public.finance_incomes where receipt_no = $1`, [rcpt])).voided_at !== null, 'gelir iptal edildi');
s = (await one(`select * from public.set_cheque_status($1, 'portfolio')`, [c1.id]));
check(s.status === 'portfolio', 'yeniden portföye alındı', s);
s = (await one(`select * from public.set_cheque_status($1, 'endorsed', $2, null, ' Kırtasiye ')`, [c1.id, today]));
check(s.status === 'endorsed' && s.endorsed_to === 'Kırtasiye', 'ciro edildi', s);
await expectError('başka müdür durum değiştiremez', async () => {
  await asUser(B.admin);
  await db.query(`select public.set_cheque_status($1, 'portfolio')`, [c1.id]);
}, 'FINANCE_NOT_ADMIN');

console.log('Ücrete bağlı çek: taksitlere işlenir');
await asUser(A.admin);
const fee = (await one(`insert into public.finance_fees (student_id, title, total) values ($1, 'YKS', 10000) returning id`, [A.student])).id;
await db.query(`insert into public.finance_installments (fee_id, due_on, amount) values ($1, '2026-10-01', 5000), ($1, '2026-11-01', 5000)`, [fee]);
await expectError('ücret öğrenciyle aynı olmalı',
  () => db.query(`insert into public.finance_cheques (direction, party_name, fee_id, amount, due_on) values ('received', 'X', $1, 5, current_date)`, [fee]), 'FINANCE_BAD_FEE');
const c2 = await one(`insert into public.finance_cheques (direction, party_name, student_id, fee_id, amount, due_on)
  values ('received', 'Veli', $1, $2, 6000, current_date) returning id`, [A.student, fee]);
s = (await one(`select * from public.set_cheque_status($1, 'collected', $2, $3)`, [c2.id, today, acc]));
const paid = await rows(`select amount from public.finance_payments where receipt_no = $1 order by amount desc`, [s.receipt_no]);
check(paid.length === 2 && Number(paid[0].amount) === 5000 && Number(paid[1].amount) === 1000, 'iki taksite dağıtıldı', paid);
s = (await one(`select * from public.set_cheque_status($1, 'portfolio')`, [c2.id]));
const open = await one(`select sum(paid_amount) p from public.finance_installments where fee_id = $1`, [fee]);
check(Number(open.p) === 0, 'geri alınınca taksit açıldı', open);
const big = await one(`insert into public.finance_cheques (direction, party_name, student_id, fee_id, amount, due_on)
  values ('received', 'Veli', $1, $2, 99999, current_date) returning id`, [A.student, fee]);
await expectError('borçtan büyük çek ücrete yazılamaz',
  () => db.query(`select public.set_cheque_status($1, 'collected', $2)`, [big.id, today]), 'FINANCE_OVERPAYMENT');
check((await one(`select status from public.finance_cheques where id = $1`, [big.id])).status === 'portfolio', 'hata durumu değiştirmez');
await db.query(`delete from public.finance_cheques where id = $1`, [big.id]);
ok('portföydeki kayıt silinir');

console.log('Verilen çek: gidere işlenir');
const c3 = await one(`insert into public.finance_cheques (direction, serial_no, party_name, student_id, amount, due_on)
  values ('given', '777', 'Ev Sahibi', $1, 45000, current_date) returning *`, [A.student]);
check(c3.status === 'issued' && c3.student_id === null, 'verilen çek öğrenciye bağlanmaz', c3);
s = (await one(`select * from public.set_cheque_status($1, 'paid', $2, $3)`, [c3.id, today, acc]));
const e = await one(`select amount, category, account_id, note from public.finance_expenses where id = $1`, [s.expense_id]);
check(Number(e.amount) === 45000 && e.category === 'other' && e.account_id === acc && e.note.includes('777'), 'gider yazıldı', e);
const expId = s.expense_id;
s = (await one(`select * from public.set_cheque_status($1, 'issued')`, [c3.id]));
check(s.status === 'issued' && s.expense_id === null, 'geri alındı', s);
check((await rows(`select id from public.finance_expenses where id = $1`, [expId])).length === 0, 'gider silindi');
s = (await one(`select * from public.set_cheque_status($1, 'cancelled', $2)`, [c3.id, today]));
check(s.status === 'cancelled', 'iptal edildi', s);

console.log('Silmeler');
await db.query(`delete from public.staff_members where id = $1`, [sec.id]);
check((await rows(`select id from public.staff_leaves where staff_id = $1`, [sec.id])).length === 0, 'kart silinince izinler gider');
const keep = await one(`select staff_id, staff_name, amount from public.finance_expenses where id = $1`, [exp.id]);
check(keep.staff_id === null && keep.staff_name === 'Hale Yurt', 'ödeme kaydı adıyla kalır', keep);
await db.query(`delete from public.teachers where id = $1`, [A.teacher]);
check((await one(`select teacher_id from public.staff_members where id = $1`, [linked.id])).teacher_id === null, 'öğretmen silinince kart kalır');
await asSuper();
await db.query(`delete from public.organizations where id = $1`, [B.org]);
ok('kurum silinebilir');

console.log('Geri alma ve yeniden uygulama');
const name = '20261109150000_staff_cheques';
const later = migs.filter((f) => f > `${name}.sql`);
for (const f of [...later].reverse()) await db.exec(read(rbDir, f.replace('.sql', '.down.sql')));
await db.exec(read(rbDir, `${name}.down.sql`));
for (const t of ['staff_members', 'staff_leaves', 'finance_cheques']) {
  check((await one(`select to_regclass('public.${t}') t`)).t === null, `${t} kaldırıldı`);
}
check(Number((await one(`select amount from public.finance_expenses where id = $1`, [exp.id])).amount) === 25000, 'gider kaldı');
await db.exec(read(migDir, `${name}.sql`));
for (const f of later) await db.exec(read(migDir, f));
check((await one(`select to_regclass('public.finance_cheques') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
