// Öğretmen ödemeleri (20261109140000_teacher_pay): ücret ve ödeme yalnızca
// kurum müdürünün; kurum ve ad sunucuda yazılır, öğretmen silinse de kayıt kalır.
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
      privacy_version: '1.0' })])).id;
}
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  const admin = await signUp(code, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(admin);
  const teacher = (await one(`insert into public.teachers (full_name, branches) values ($1, '{Matematik}') returning id`,
    [`${name} Öğretmen`])).id;
  return { org, admin, coach, teacher };
}

const A = await school('Bal Akademi', 'ADMINTP1');
const B = await school('Arı Kurs', 'ADMINTP2');

console.log('Müdür ücret kaydeder');
await asUser(A.admin);
const rate = await one(`insert into public.teacher_pay_rates (teacher_id, pay_type, amount, note, org_id)
  values ($1, 'hourly', 300, '  Ayda bir öder  ', $2) returning *`, [A.teacher, B.org]);
check(rate.org_id === A.org && rate.note === 'Ayda bir öder', 'kurum sunucuda yazıldı, not kırpıldı', rate);
await db.query(`update public.teacher_pay_rates set pay_type = 'fixed', amount = 20000 where teacher_id = $1`, [A.teacher]);
const updated = await one(`select pay_type, amount from public.teacher_pay_rates where teacher_id = $1`, [A.teacher]);
check(updated.pay_type === 'fixed' && Number(updated.amount) === 20000, 'sabit tutara çevrildi', updated);
await expectError('başka kurumun öğretmenine ücret yazılamaz',
  () => db.query(`insert into public.teacher_pay_rates (teacher_id, amount) values ($1, 100)`, [B.teacher]), 'FINANCE_BAD_TEACHER');
await expectError('geçersiz ödeme şekli reddedilir',
  () => db.query(`update public.teacher_pay_rates set pay_type = 'x' where teacher_id = $1`, [A.teacher]), 'check');
await expectError('eksi tutar reddedilir',
  () => db.query(`update public.teacher_pay_rates set amount = -1 where teacher_id = $1`, [A.teacher]), 'check');

console.log('Ödeme gider olarak öğretmene bağlanır');
const exp = await one(`insert into public.finance_expenses (spent_on, category, amount, teacher_id, teacher_name, note)
  values (current_date, 'salary', 21600, $1, 'sahte', '72 ders saati') returning *`, [A.teacher]);
check(exp.teacher_name === 'Bal Akademi Öğretmen' && exp.org_id === A.org, 'öğretmen adı sunucudan', exp);
await expectError('başka kurumun öğretmenine ödeme yazılamaz',
  () => db.query(`insert into public.finance_expenses (spent_on, category, amount, teacher_id) values (current_date, 'salary', 10, $1)`, [B.teacher]), 'FINANCE_BAD_TEACHER');
await expectError('gider aynı anda koça ve öğretmene bağlanamaz',
  () => db.query(`insert into public.finance_expenses (spent_on, category, amount, coach_id, teacher_id) values (current_date, 'salary', 10, $1, $2)`, [A.coach, A.teacher]), 'finance_expenses_one_payee');
const plain = await one(`insert into public.finance_expenses (spent_on, category, amount, teacher_name)
  values (current_date, 'rent', 10, 'sahte') returning teacher_name`);
check(plain.teacher_name === null, 'öğretmensiz giderde ad yazılamaz', plain);
await db.query(`update public.finance_expenses set note = 'güncel', teacher_name = 'sahte' where id = $1`, [exp.id]);
check((await one(`select teacher_name from public.finance_expenses where id = $1`, [exp.id])).teacher_name === 'Bal Akademi Öğretmen',
  'güncellemede ad değiştirilemez');

console.log('Yetki');
await asUser(B.admin);
check((await rows(`select teacher_id from public.teacher_pay_rates`)).length === 0, 'öteki müdür ücretleri görmez');
check((await rows(`select id from public.finance_expenses where teacher_id is not null`)).length === 0, 'öteki müdür ödemeleri görmez');
await db.query(`update public.teacher_pay_rates set amount = 1 where teacher_id = $1`, [A.teacher]);
await asUser(A.coach);
check((await rows(`select teacher_id from public.teacher_pay_rates`)).length === 0, 'koç ücretleri görmez');
await expectError('koç ücret yazamaz',
  () => db.query(`insert into public.teacher_pay_rates (teacher_id, amount) values ($1, 100)`, [A.teacher]), 'FINANCE_NOT_ADMIN');
await asAnon();
await expectError('anonim okuyamaz', () => db.query(`select * from public.teacher_pay_rates`), 'permission');
await asUser(A.admin);
check(Number((await one(`select amount from public.teacher_pay_rates where teacher_id = $1`, [A.teacher])).amount) === 20000,
  'öteki müdürün güncellemesi etkisiz kaldı');

console.log('Öğretmen silinince');
await db.query(`delete from public.teachers where id = $1`, [A.teacher]);
check((await rows(`select teacher_id from public.teacher_pay_rates`)).length === 0, 'ücret satırı silinir');
const kept = await one(`select teacher_id, teacher_name, amount from public.finance_expenses where id = $1`, [exp.id]);
check(kept.teacher_id === null && kept.teacher_name === 'Bal Akademi Öğretmen' && Number(kept.amount) === 21600,
  'ödeme kaydı adıyla kalır', kept);

console.log('Geri alma ve yeniden uygulama');
const name = '20261109140000_teacher_pay';
await asSuper();
const later = migs.filter((f) => f > `${name}.sql`);
for (const f of [...later].reverse()) await db.exec(read(rbDir, f.replace('.sql', '.down.sql')));
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.teacher_pay_rates') t`)).t === null, 'tablo kaldırıldı');
const col = await rows(`select 1 from information_schema.columns where table_name = 'finance_expenses' and column_name = 'teacher_id'`);
check(col.length === 0, 'gider sütunu kaldırıldı');
check(Number((await one(`select amount from public.finance_expenses where id = $1`, [exp.id])).amount) === 21600, 'gider kaldı');
await db.exec(read(migDir, `${name}.sql`));
for (const f of later) await db.exec(read(migDir, f));
check((await one(`select to_regclass('public.teacher_pay_rates') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
