// Avatar: yeni parçalar ve yeni açılma kuralları (toplam soru, odaklanma
// süresi, bitirilen konu, deneme sayısı); geri alma kuşanılmış yeni parçaları
// avatardan çıkarır.
// hesap silmede temizlik ve geri alma testleri.
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
async function school(name, adminCode) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [adminCode, org]);
  const admin = await signUp(adminCode, `${name} Müdür`);
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, `${name} Koç`);
  await asUser(coach);
  const code = (await one(`select public.create_invite('student', null, 10) c`)).c;
  return { admin, coach, code };
}


const A = await school('Bal Akademi', 'ADMINAM1');
const elif = await signUp(A.code, 'Elif Yılmaz');
const can = await signUp(A.code, 'Can Kaya');

console.log('Yeni ücretsiz parçalar');
await asUser(elif);
await db.query(`update public.profiles set avatar = '{"hair": 22, "skin": 19, "outfit": 29, "accessory": 38}' where id = $1`, [elif]);
check((await one(`select avatar->>'hair' h from public.profiles where id = $1`, [elif])).h === '22', 'başörtüsü, zeytin ten, okul forması, fiyonk kuşanılır');
await expectError('kilitli yeni parça kuşanılamaz', () => db.query(`update public.profiles set avatar = '{"accessory": 39}' where id = $1`, [elif]), 'AVATAR_ITEM_LOCKED');

const claim = async () => (await one(`select public.claim_avatar_unlocks() c`)).c;
check((await claim()).length === 0, 'henüz yeni ödül yok');

console.log('Toplam soru');
const mat = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
await db.query(`insert into public.question_logs (student_id, subject_id, correct, wrong, blank, logged_on) values ($1, $2, 200, 40, 20, current_date)`, [elif, mat]);
let c = await claim();
check(c.includes(39) && !c.includes(25), '260 soru: kalem açılır, 500 soru örgüsü açılmaz', c);
await db.query(`insert into public.question_logs (student_id, subject_id, correct, logged_on) values ($1, $2, 300, current_date - 20)`, [elif, mat]);
c = await claim();
check(c.includes(25) && !c.includes(41), '560 soru: örgü saç açılır, 2000 soru anteni açılmaz', c);

console.log('Odaklanma süresi');
await db.query(`insert into public.study_sessions (student_id, started_at, duration_sec) values ($1, now() - interval '2 days', 43200), ($1, now() - interval '3 days', 43200), ($1, now() - interval '4 days', 43200), ($1, now() - interval '5 days', 43200), ($1, now() - interval '6 days', 36000)`, [elif]);
c = await claim();
check(c.includes(33) && !c.includes(43), '58 saat: astronot açılır, 100 saat halesi açılmaz', c);

console.log('Bitirilen konu');
await asSuper();
const topics = (await db.query(`select id from public.topics order by id limit 25`)).rows.map((r) => r.id);
await asUser(elif);
for (const t of topics.slice(0, 24)) {
  await db.query(`insert into public.topic_progress (student_id, topic_id, status) values ($1, $2, 'done')`, [elif, t]);
}
check(!(await claim()).includes(31), '24 konu: önlük açılmaz');
await db.query(`insert into public.topic_progress (student_id, topic_id, status) values ($1, $2, 'done')`, [elif, topics[24]]);
check((await claim()).includes(31), '25 konu: laboratuvar önlüğü açılır');

console.log('Deneme sayısı');
await asUser(A.coach);
for (let i = 0; i < 5; i++) {
  await db.query(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', $2)`, [elif, `Deneme ${i + 1}`]);
}
await asUser(elif);
c = await claim();
check(c.includes(32) && !c.includes(42), '5 deneme: forma açılır, 10 deneme kepi açılmaz', c);

console.log('Açılan yeni parçalar kuşanılır; başkası etkilenmez');
await db.query(`update public.profiles set avatar = '{"hair": 25, "skin": 18, "outfit": 33, "accessory": 39}' where id = $1`, [elif]);
ok('örgü saç + astronot + kalem kuşanıldı');
await asUser(can);
check((await claim()).length === 0, 'Can hiçbir şey açmadı');
await expectError('Can astronotu kuşanamaz', () => db.query(`update public.profiles set avatar = '{"outfit": 33}' where id = $1`, [can]), 'AVATAR_ITEM_LOCKED');

console.log('Geri alma ve yeniden uygulama');
const name = '20261018170000_avatars_more';
await asSuper();
await db.query(`insert into public.user_unlocked_items (user_id, item_id, tenant_id) select $1, i, tenant_id from public.profiles, unnest(array[25, 33]::smallint[]) i where id = $1`, [can]);
await db.query(`update public.profiles set avatar = '{"hair": 25, "skin": 6, "outfit": 33, "accessory": 15}' where id = $1`, [can]);
// Sonraki migration'lar ters sırayla önce geri alınır (düello ödülleri).
await db.exec(read(rbDir, '20261018230000_duels.down.sql'));
await db.exec(read(rbDir, `${name}.down.sql`));
const after = await one(`select (select avatar from public.profiles where id = $1) e, (select avatar from public.profiles where id = $2) c, (select count(*)::int from public.avatar_items) n`, [elif, can]);
check(after.n === 17, 'yeni parçalar silindi', after.n);
check(JSON.stringify(after.e) === '{}', 'Elif: tümü yeni parçaysa avatar boşalır', after.e);
check(after.c.skin === 6 && after.c.accessory === 15 && after.c.hair === undefined, 'Can: eski parçalar korunur, yeniler çıkar', after.c);
await asUser(elif);
check(!(await claim()).length, 'eski kurallarla yeni bir şey açılmaz');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select count(*)::int n from public.avatar_items`)).n === 43, 'yeniden uygulandı');
await db.exec(read(migDir, '20261018230000_duels.sql'));
await asUser(elif);
check((await claim()).includes(33), 'yeniden uygulanınca hak edilenler yine açılır');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
