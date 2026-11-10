// Kurum finansı (20261105100000_finance): yalnızca kurum müdürü okur ve yazar;
// kurum ve adlar sunucuda yazılır, öğrenci silinse de mali kayıt kalır.
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

const A = await school('Bal Akademi', 'ADMINFA1');
const B = await school('Arı Kurs', 'ADMINFB1');

console.log('Müdür kayıt tutar');
await asUser(A.admin);
const fee = await one(`insert into public.finance_fees (student_id, title, total, student_name, org_id)
  values ($1, '  YKS kursu  ', 30000, 'sahte', $2) returning *`, [A.student, B.org]);
check(fee.org_id === A.org && fee.student_name === 'Bal Akademi Öğrenci' && fee.title === 'YKS kursu',
  'kurum ve öğrenci adı sunucuda yazıldı (istemcinin gönderdiği yok sayıldı)', fee);
await db.query(`insert into public.finance_installments (fee_id, due_on, amount)
  values ($1, '2026-10-01', 10000), ($1, '2026-11-01', 10000), ($1, '2026-12-01', 10000)`, [fee.id]);
const inst = await rows(`select * from public.finance_installments where fee_id = $1 order by due_on`, [fee.id]);
check(inst.length === 3 && inst.every((r) => r.org_id === A.org), 'taksitler kuruma bağlandı');
const receipt = (await one(`select public.record_payment($1, 10000, '2026-10-03', 'transfer', null, null, $2) r`, [fee.id, inst[0].id])).r.receipt_no;
await db.query(`update public.finance_installments set paid_on = null, method = 'cash' where id = $1`, [inst[1].id]);
const after = await rows(`select paid_on, method from public.finance_installments where fee_id = $1 order by due_on`, [fee.id]);
check(after[0].method === 'transfer' && after[1].method === null, 'ödenmemiş taksitte ödeme şekli tutulmaz', after);

const exp = await one(`insert into public.finance_expenses (spent_on, category, amount, coach_id, note)
  values ('2026-10-31', 'salary', 25000, $1, '  Ekim  ') returning *`, [A.coach]);
check(exp.coach_name === 'Bal Akademi Koç' && exp.note === 'Ekim', 'maaş gideri koça bağlandı', exp);
await db.query(`insert into public.coach_pay_rates (coach_id, monthly_salary, per_student) values ($1, 20000, 500)`, [A.coach]);
await db.query(`update public.coach_pay_rates set per_student = 600 where coach_id = $1`, [A.coach]);
check(Number((await one(`select per_student from public.coach_pay_rates where coach_id = $1`, [A.coach])).per_student) === 600,
  'koç oranı güncellendi');

console.log('Kurallar');
await expectError('başka kurumun öğrencisine ücret yazılamaz', () =>
  db.query(`insert into public.finance_fees (student_id, title, total) values ($1, 'X', 100)`, [B.student]), 'FINANCE_BAD_STUDENT');
await expectError('başka kurumun koçuna gider yazılamaz', () =>
  db.query(`insert into public.finance_expenses (spent_on, category, amount, coach_id) values (current_date, 'bonus', 10, $1)`, [B.coach]), 'FINANCE_BAD_COACH');
await expectError('başka kurumun koçuna oran yazılamaz', () =>
  db.query(`insert into public.coach_pay_rates (coach_id) values ($1)`, [B.coach]), 'FINANCE_BAD_COACH');
await expectError('negatif tutar olmaz', () =>
  db.query(`insert into public.finance_expenses (spent_on, category, amount) values (current_date, 'rent', -5)`), 'check');
await expectError('bilinmeyen gider türü olmaz', () =>
  db.query(`insert into public.finance_expenses (spent_on, category, amount) values (current_date, 'fun', 5)`), 'check');
await db.query(`update public.finance_fees set org_id = $1, student_id = $2, student_name = 'X', title = 'Yeni ad' where id = $3`,
  [B.org, B.student, fee.id]);
const moved = await one(`select org_id, student_id, student_name, title from public.finance_fees where id = $1`, [fee.id]);
check(moved.org_id === A.org && moved.student_id === A.student && moved.title === 'Yeni ad',
  'kurum ve öğrenci değiştirilemez, başlık değişir', moved);

await asUser(B.admin);
check((await rows(`select id from public.finance_fees`)).length === 0, 'öteki müdür bu kurumun ücretlerini görmez');
check((await rows(`select id from public.finance_expenses`)).length === 0, 'öteki müdür giderleri görmez');
await expectError('öteki müdür bu kurumun ücretine taksit ekleyemez', () =>
  db.query(`insert into public.finance_installments (fee_id, due_on, amount) values ($1, current_date, 10)`, [fee.id]), 'FINANCE_BAD_FEE');
const upd = await db.query(`update public.finance_installments set paid_on = current_date where fee_id = $1`, [fee.id]);
check(upd.affectedRows === 0, 'öteki müdür taksiti işaretleyemez', upd.affectedRows);

for (const [who, n] of [[A.coach, 'koç'], [A.student, 'öğrenci'], [A.parent, 'veli']]) {
  await asUser(who);
  const seen = (await rows(`select id from public.finance_fees`)).length
    + (await rows(`select id from public.finance_installments`)).length
    + (await rows(`select coach_id from public.coach_pay_rates`)).length
    + (await rows(`select id from public.finance_expenses`)).length;
  check(seen === 0, `${n} hiçbir finans satırını görmez`, seen);
  await expectError(`${n} gider yazamaz`, () =>
    db.query(`insert into public.finance_expenses (spent_on, category, amount) values (current_date, 'rent', 5)`), 'FINANCE_NOT_ADMIN');
}
await asAnon();
await expectError('oturumsuz okunamaz', () => db.query(`select * from public.finance_fees`), 'permission');

console.log('Öğrenci silinince mali kayıt kalır');
await asUser(A.admin);
await db.query(`select public.delete_student_account($1)`, [A.student]);
await asUser(A.admin);
const kept = await one(`select student_id, student_name,
    (select count(*)::int from public.finance_installments i where i.fee_id = f.id) n
  from public.finance_fees f where id = $1`, [fee.id]);
check(kept.student_id === null && kept.student_name === 'Bal Akademi Öğrenci' && kept.n === 3,
  'ücret ve taksitler adıyla duruyor', kept);
await asSuper();
await db.query(`delete from auth.users where id = $1`, [A.coach]);
await asUser(A.admin);
const paid = await one(`select coach_id, coach_name from public.finance_expenses where id = $1`, [exp.id]);
check(paid.coach_id === null && paid.coach_name === 'Bal Akademi Koç', 'koç silinince maaş gideri adıyla kalır', paid);
check((await rows(`select coach_id from public.coach_pay_rates`)).length === 0, 'koç silinince oranı silinir');
await expectError('ödemesi olan ücret silinemez', () => db.query(`delete from public.finance_fees where id = $1`, [fee.id]), 'FINANCE_HAS_PAYMENTS');
await db.query(`select public.void_receipt($1)`, [receipt]);
await db.query(`delete from public.finance_fees where id = $1`, [fee.id]);
check((await rows(`select id from public.finance_installments where fee_id = $1`, [fee.id])).length === 0,
  'ücret silinince taksitleri de silinir');

console.log('Geri alma ve yeniden uygulama');
// Geri alma ters sırayla: önce üstüne kurulan hatırlatma migration'ı.
const name = '20261105100000_finance';
const next = '20261105110000_finance_reminders';
await asSuper();
// Üstüne kurulan finance_plus önce geri alınır.
const laterDeps = ['20261106100000_finance_plus', '20261106150000_bulk_fee_duplicates', '20261109140000_teacher_pay', '20261109150000_staff_cheques'].filter((n) => migs.includes(`${n}.sql`));
for (const l of [...laterDeps].reverse()) await db.exec(read(rbDir, `${l}.down.sql`));
await db.exec(read(rbDir, `${next}.down.sql`));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.finance_fees') t`)).t === null, 'tablolar kaldırıldı');
await db.exec(read(migDir, `${name}.sql`));
await db.exec(read(migDir, `${next}.sql`));
for (const l of laterDeps) await db.exec(read(migDir, `${l}.sql`));
check((await one(`select to_regclass('public.finance_fees') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
