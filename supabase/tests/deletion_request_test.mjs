// Hesap silme talebi: öğrenci başlatır, koçuna (koçu yoksa müdürüne) bildirim
// gider, tekrar talep engellenir, silme kararı koçta kalır, dershane
// izolasyonu ve geri alma.
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
const count = async (sql, p = []) => (await one(sql, p)).c;
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
  return { admin, coach, org, code: (await one(`select public.create_invite('student', null, 10) c`)).c };
}

const A = await school('Bal Akademi', 'ADMINDR1');
await asUser(A.admin);
const coach2 = await signUp((await one(`select public.create_invite('coach') c`)).c, 'Bal Koç 2');
const elif = await signUp(A.code, 'Elif Yılmaz');
const can = await signUp(A.code, 'Can Kaya');
const B = await school('Yıldız', 'ADMINDR2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

// --- Öğrenci talebi başlatır ---
await asUser(elif);
const at = (await one(`select public.request_account_deletion() at`)).at;
check(at != null, 'öğrenci hesap silme talebi oluşturur');
const row = await one(`select student_id, tenant_id from public.account_deletion_requests`);
await asSuper();
const tenantA = (await one(`select tenant_id from public.organizations where id = $1`, [A.org])).tenant_id;
check(row?.student_id === elif && row.tenant_id === tenantA, 'talep öğrencinin dershanesiyle kaydedilir (tenant_id sunucuda)', row);

const n = await one(`select user_id, data, ref_id, tenant_id from public.notifications where kind = 'deletion_request'`);
check(n?.user_id === A.coach && n.ref_id === elif && n.data.student === 'Elif Yılmaz'
  && n.data.route === `/coach/students/${elif}` && n.tenant_id === tenantA, 'koça bildirim gider (öğrenci adı ve rota)', n);
check(await count(`select count(*)::int c from public.notifications where kind = 'deletion_request' and user_id = $1`, [coach2]) === 0,
  'başka koça bildirim gitmez');

await asUser(elif);
await expectError('tekrar talep engellenir', () => db.query(`select public.request_account_deletion()`), 'ALREADY_REQUESTED');
await asSuper();
check(await count(`select count(*)::int c from public.notifications where kind = 'deletion_request'`) === 1, 'tekrar denemede yeni bildirim yok');

// --- Talep silmez; karar koçta ---
check(await count(`select count(*)::int c from public.profiles where id = $1`, [elif]) === 1, 'talep hesabı silmez');
await expectError('öğrenci yine kendi hesabını silemez', async () => { await asUser(elif); await db.query(`select public.delete_my_account()`); }, 'STUDENT_DELETE_BY_COACH');

// --- Doğrudan yazma yok ---
await asUser(can);
await expectError('tabloya doğrudan eklenemez', () => db.query(`insert into public.account_deletion_requests (student_id) values ($1)`, [can]));
await asUser(elif);
await expectError('talep tarihi değiştirilemez', () => db.query(`update public.account_deletion_requests set requested_at = now() - interval '1 year'`));

// --- Kim görür ---
await asUser(A.coach);
check(await count(`select count(*)::int c from public.account_deletion_requests where student_id = $1`, [elif]) === 1, 'koç öğrencisinin talebini görür');
await asUser(A.admin);
check(await count(`select count(*)::int c from public.account_deletion_requests`) === 1, 'kurum müdürü talebi görür');
await asUser(coach2);
check(await count(`select count(*)::int c from public.account_deletion_requests`) === 0, 'başka koç talebi görmez');
await asUser(can);
check(await count(`select count(*)::int c from public.account_deletion_requests`) === 0, 'başka öğrenci talebi görmez');
await asUser(B.coach);
check(await count(`select count(*)::int c from public.account_deletion_requests`) === 0, 'başka dershane talebi görmez');
await asUser(B.admin);
check(await count(`select count(*)::int c from public.account_deletion_requests`) === 0, 'başka dershanenin müdürü talebi görmez');
await asAnon();
await expectError('giriş yapmayan talep açamaz', () => db.query(`select public.request_account_deletion()`));

// --- Rol kontrolü ---
await asUser(A.coach);
await expectError('koç talep açamaz', () => db.query(`select public.request_account_deletion()`), 'NOT_A_STUDENT');

// --- Geri alma ve 24 saat bildirim sınırı ---
await asUser(coach2);
await db.query(`delete from public.account_deletion_requests`);
await asSuper();
check(await count(`select count(*)::int c from public.account_deletion_requests`) === 1, 'koç talebi silemez (karar: hesabı silmek)');
await asUser(elif);
await db.query(`delete from public.account_deletion_requests`);
check(await count(`select count(*)::int c from public.account_deletion_requests`) === 0, 'öğrenci talebini geri alır');
await db.query(`select public.request_account_deletion()`);
await asSuper();
check(await count(`select count(*)::int c from public.account_deletion_requests`) === 1
  && await count(`select count(*)::int c from public.notifications where kind = 'deletion_request'`) === 1,
  'geri alıp yeniden isteyince talep açılır ama 24 saat içinde yeni bildirim gitmez');

// --- Koçu olmayan öğrenci: müdüre gider ---
await asSuper();
await db.query(`delete from public.coach_students where student_id = $1`, [zeynep]);
await asUser(zeynep);
await db.query(`select public.request_account_deletion()`);
await asSuper();
const nb = await one(`select user_id, data from public.notifications where kind = 'deletion_request' and ref_id = $1`, [zeynep]);
check(nb?.user_id === B.admin && nb.data.route === `/admin/students/${zeynep}`, 'koçu yoksa kurum müdürüne bildirim gider', nb);
check(await count(`select count(*)::int c from public.notifications where kind = 'deletion_request' and user_id in ($1, $2)`, [A.admin, A.coach]) === 1,
  'başka dershanenin yöneticisine bildirim gitmez');

// --- Koç silince talep de gider ---
await asUser(A.coach);
await db.query(`select public.delete_student_account($1)`, [elif]);
await asSuper();
check(await count(`select count(*)::int c from public.account_deletion_requests where student_id = $1`, [elif]) === 0, 'koç hesabı silince talep de silinir');

// --- Geri alma ve yeniden uygulama ---
const mig = migs.find((f) => f.includes('account_deletion_requests'));
await db.exec(read(rbDir, mig.replace('.sql', '.down.sql')));
const gone = await one(`select to_regclass('public.account_deletion_requests') t,
  to_regprocedure('public.request_account_deletion()') f,
  (select count(*)::int from public.notifications where kind = 'deletion_request') n`);
check(gone.t === null && gone.f === null && gone.n === 0, 'geri alma: tablo, fonksiyon ve bildirimler kaldırıldı', gone);
await expectError('geri alma: eski bildirim türü kısıtı geri geldi', () =>
  db.query(`insert into public.notifications (user_id, kind) values ($1, 'deletion_request')`, [A.coach]), 'notifications_kind_check');
await asUser(A.coach);
await db.query(`insert into public.tasks (coach_id, student_id, title) values ($1, $2, 'Geri alma sonrası')`, [A.coach, can]);
ok('geri alma sonrası görev/bildirim akışı çalışır');
await asSuper();
await db.exec(read(migDir, mig));
await asUser(can);
await db.query(`select public.request_account_deletion()`);
check(await count(`select count(*)::int c from public.account_deletion_requests`) === 1, 'yeniden uygulama başarılı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
