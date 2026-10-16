// Başarı sıralaması: müdür anahtarı, son 5 deneme ortalaması, TYT/AYT ayrımı,
// TYT ilk 5 ödülleri, kurumlar arası izolasyon ve geri alma testleri.
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
  return { org, admin, coach, code };
}

const A = await school('Bal Akademi', 'ADMINSR1');
const names = ['Can Kaya', 'Elif Yılmaz', 'Ali Demir', 'Deniz Su', 'Ece Tan', 'Fatma Ak'];
const s = {};
for (const n of names) s[n.split(' ')[0]] = await signUp(A.code, n);
const B = await school('Yıldız Dershanesi', 'ADMINSR2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

// Deneme ekleme: toplam net = doğru sayısı (yanlış yok).
const subj = async (code) => (await one(`select id from public.subjects where code = $1`, [code])).id;
const tytMat = await subj('TYT_MAT');
const aytMat = await subj('AYT_MAT');
let day = 0;
async function exam(coach, student, type, net, field = null) {
  await asUser(coach);
  day++;
  const id = (await one(`insert into public.exams (student_id, exam_type, field, name, taken_on)
    values ($1, $2, $3, 'Deneme', date '2026-01-01' + $4::int) returning id`, [student, type, field, day])).id;
  await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct) values ($1, $2, $3)`,
    [id, type === 'TYT' ? tytMat : aytMat, net]);
}

// Elif: en eski denemesi 100, sonraki 5 denemesi 50 → son 5 ortalaması 50.
await exam(A.coach, s.Elif, 'TYT', 100);
for (let i = 0; i < 5; i++) await exam(A.coach, s.Elif, 'TYT', 50);
// Can: tek deneme 60 (en az 1 deneme yeterli).
await exam(A.coach, s.Can, 'TYT', 60);
await exam(A.coach, s.Ali, 'TYT', 46);
await exam(A.coach, s.Ali, 'TYT', 44);
await exam(A.coach, s.Deniz, 'TYT', 40);
await exam(A.coach, s.Ece, 'TYT', 35);
await exam(A.coach, s.Fatma, 'TYT', 30);
await exam(A.coach, s.Fatma, 'AYT', 70, 'SAY');
await exam(A.coach, s.Can, 'AYT', 20, 'SAY');
await exam(A.coach, s.Ece, 'AYT', 50, 'EA');
await exam(B.coach, zeynep, 'TYT', 110);

// --- Kapalıyken
await asUser(s.Can);
await expectError('kapalıyken öğrenci sıralamayı göremez', () => db.query(`select * from public.success_leaderboard('TYT')`), 'RANKING_DISABLED');
let st = await one(`select * from public.my_success_status()`);
check(st.enabled === false && st.reward_rank === null, 'kapalıyken durum: kapalı, ödül yok', st);
await asUser(A.coach);
await expectError('kapalıyken koç da göremez', () => db.query(`select * from public.success_leaderboard('TYT')`), 'RANKING_DISABLED');
await asUser(A.admin);
let rows = (await db.query(`select * from public.success_leaderboard('TYT')`)).rows;
check(rows.length === 6 && rows.every((r) => r.reward_rank === null), 'müdür kapalıyken önizler, ödül görünmez', rows.map((r) => r.reward_rank));

// --- Anahtar yalnızca müdürde
await asUser(s.Can);
await expectError('öğrenci sıralamayı açamaz', () => db.query(`select public.set_success_ranking(true)`), 'NOT_ALLOWED');
await expectError('öğrenci kolonu doğrudan değiştiremez', () => db.query(`update public.organizations set success_ranking_enabled = true`));
await asUser(A.coach);
await expectError('koç sıralamayı açamaz', () => db.query(`select public.set_success_ranking(true)`), 'NOT_ALLOWED');
await asUser(A.admin);
await db.query(`select public.set_success_ranking(true)`);
await asSuper();
check((await one(`select success_ranking_enabled e from public.organizations where id = $1`, [A.org])).e === true, 'müdür kendi kurumunda açar');
check((await one(`select success_ranking_enabled e from public.organizations where id = $1`, [B.org])).e === false, 'başka kurum etkilenmez');

// --- TYT sıralaması
await asUser(s.Fatma);
rows = (await db.query(`select * from public.success_leaderboard('TYT')`)).rows;
const order = rows.map((r) => [r.display_name, Number(r.avg_net), r.rank, r.reward_rank]);
check(JSON.stringify(rows.map((r) => r.display_name)) === JSON.stringify(['Ca***', 'El***', 'Al***', 'De***', 'Ec***', 'Fa***']),
  'TYT: son 5 deneme ortalamasına göre sıralanır (eski 100 net hesaba katılmaz)', order);
check(Number(rows[1].avg_net) === 50 && rows[1].exam_count === 5, 'Elif: 6 denemeden son 5\'i (ortalama 50)', order[1]);
check(Number(rows[2].avg_net) === 45, 'Ali: iki denemenin ortalaması 45', order[2]);
check(JSON.stringify(rows.map((r) => r.reward_rank)) === JSON.stringify([1, 2, 3, 4, 5, null]), 'ödül: ilk 5 sıra, 6. ödülsüz', order);
check(rows.find((r) => r.is_me)?.display_name === 'Fa***', '"ben" işaretlenir');
check(rows.every((r) => /^.{1,2}\*\*\*$/u.test(r.display_name)), 'yalnızca adın ilk iki harfi görünür', rows.map((r) => r.display_name));
check(!rows.some((r) => r.display_name.startsWith('Ze')), 'başka kurumun öğrencisi yok');
check(Object.keys(rows[0]).every((k) => ['rank', 'student_id', 'display_name', 'avatar', 'avg_net', 'exam_count', 'reward_rank', 'is_me'].includes(k)),
  'yalnızca ad + baş harf, avatar ve puan döner', Object.keys(rows[0]));
const page = (await db.query(`select * from public.success_leaderboard('TYT', null, 2, 2)`)).rows;
check(page.length === 2 && page[0].display_name === 'Al***', 'sayfalama (limit/offset)', page.map((r) => r.display_name));

// --- Müdür tam adı görür, koç görmez
await asUser(A.admin);
const adminRows = (await db.query(`select * from public.success_leaderboard('TYT')`)).rows;
check(adminRows.length === 6 && adminRows.every((r) => !r.display_name.includes('***'))
  && adminRows[0].display_name === 'Can Kaya',
  'kurum müdürü öğrencilerin tam adını görür', adminRows.map((r) => r.display_name));
check(!adminRows.some((r) => r.display_name.startsWith('Ze')), 'müdür başka kurumun öğrencisini görmez');
await asUser(A.coach);
check((await db.query(`select * from public.success_leaderboard('TYT')`)).rows.every((r) => r.display_name.endsWith('***')),
  'koç yine yalnızca ilk iki harfi görür');

// --- AYT: alan zorunlu, ödül yine TYT'den
await expectError('AYT alan olmadan istenemez', () => db.query(`select * from public.success_leaderboard('AYT')`), 'INVALID_RANKING');
await expectError('geçersiz tür reddedilir', () => db.query(`select * from public.success_leaderboard('YDT')`), 'INVALID_RANKING');
rows = (await db.query(`select * from public.success_leaderboard('AYT', 'SAY')`)).rows;
check(rows.length === 2 && rows[0].display_name === 'Fa***' && rows[0].reward_rank === null && rows[1].reward_rank === 1,
  'AYT SAY ayrı sıralanır; ödül TYT sırasından gelir', rows.map((r) => [r.display_name, r.reward_rank]));
rows = (await db.query(`select * from public.success_leaderboard('AYT', 'EA')`)).rows;
check(rows.length === 1 && rows[0].display_name === 'Ec***', 'AYT EA yalnızca EA denemeleri', rows.map((r) => r.display_name));

// --- Durum ve haftalık sıralamada ödül
await asUser(s.Can);
st = await one(`select * from public.my_success_status()`);
check(st.enabled === true && st.reward_rank === 1 && st.tyt_rank === 1 && Number(st.tyt_avg_net) === 60, '1. öğrencinin durumu: taç', st);
await asUser(s.Fatma);
st = await one(`select * from public.my_success_status()`);
check(st.reward_rank === null && st.tyt_rank === 6, '6. öğrencinin ödülü yok, sırası görünür', st);
const weekly = (await db.query(`select * from public.avatar_leaderboard(50, 0)`)).rows;
check(weekly.find((r) => r.display_name === 'Can K.')?.reward_rank === 1 && weekly.find((r) => r.display_name === 'Fatma A.')?.reward_rank === null,
  'haftalık sıralamada da ödül görünür', weekly.map((r) => [r.display_name, r.reward_rank]));
await asUser(A.admin);
st = await one(`select * from public.my_success_status()`);
check(st.enabled === true && st.reward_rank === null, 'müdür durumu: açık, ödül yok', st);

// --- Diğer kurum
await asUser(zeynep);
await expectError('B kurumunda kapalı', () => db.query(`select * from public.success_leaderboard('TYT')`), 'RANKING_DISABLED');
check((await db.query(`select * from public.avatar_leaderboard(50, 0)`)).rows.every((r) => r.reward_rank === null), 'B: kapalı kurumda ödül yok');

// --- Sıra değişince ödül el değiştirir (kalıcı değil)
await exam(A.coach, s.Fatma, 'TYT', 90);  // Fatma: (30 + 90) / 2 = 60 → Can ile berabere 1.
await asUser(s.Fatma);
st = await one(`select * from public.my_success_status()`);
check(st.reward_rank === 1, 'berabere 1.ler ikisi de taç alır', st);
await asUser(s.Ece);
st = await one(`select * from public.my_success_status()`);
check(st.reward_rank === null && st.tyt_rank === 6, 'geriye düşen öğrencinin ödülü gider', st);

// --- Kapatınca ödüller gider
await asUser(A.admin);
await db.query(`select public.set_success_ranking(false)`);
await asUser(s.Can);
st = await one(`select * from public.my_success_status()`);
check(st.enabled === false && st.reward_rank === null, 'kapatınca ödül gider', st);
check((await db.query(`select * from public.avatar_leaderboard(50, 0)`)).rows.every((r) => r.reward_rank === null), 'kapatınca haftalık sıralamada ödül yok');

// --- Pasif dershane
await asUser(A.admin);
await db.query(`select public.set_success_ranking(true)`);
await asSuper();
await db.query(`update public.tenants set is_active = false where id = (select tenant_id from public.organizations where id = $1)`, [A.org]);
await asUser(s.Can);
await expectError('pasif dershanede sıralama yok', () => db.query(`select * from public.success_leaderboard('TYT')`), 'NOT_ALLOWED');
check((await one(`select * from public.my_success_status()`)).enabled === false, 'pasif dershanede durum kapalı');
await asUser(A.admin);
await expectError('pasif dershanede müdür açıp kapatamaz', () => db.query(`select public.set_success_ranking(false)`), 'NOT_ALLOWED');
await asSuper();
await db.query(`update public.tenants set is_active = true where id = (select tenant_id from public.organizations where id = $1)`, [A.org]);

// --- Geri alma ve yeniden uygulama
const fullMig = migs.find((f) => f.includes('ranking_admin_full_names'));
await asSuper();
await db.exec(read(rbDir, fullMig.replace('.sql', '.down.sql')));
await asUser(A.admin);
check((await db.query(`select * from public.success_leaderboard('TYT')`)).rows.every((r) => r.display_name.endsWith('***')),
  'geri alma: müdür de yeniden kısaltılmış adı görür');
await asSuper();
const shortMig = migs.find((f) => f.includes('success_ranking_short_names'));
await db.exec(read(rbDir, shortMig.replace('.sql', '.down.sql')));
await asUser(s.Can);
const longNames = (await db.query(`select display_name from public.success_leaderboard('TYT')`)).rows;
check(longNames.some((r) => r.display_name === 'Can K.'), 'kısa ad geri alınınca "Can K." biçimine döner', longNames);
await asSuper();
const mig = migs.find((f) => f.endsWith('_success_ranking.sql'));
await db.exec(read(rbDir, mig.replace('.sql', '.down.sql')));
const gone = await one(`select
  (select count(*)::int from information_schema.columns where table_name = 'organizations' and column_name = 'success_ranking_enabled') c,
  to_regprocedure('public.success_leaderboard(text, text, int, int)') f`);
check(gone.c === 0 && gone.f === null, 'geri alma: kolon ve fonksiyonlar kaldırıldı', gone);
await asUser(s.Can);
const old = (await db.query(`select * from public.avatar_leaderboard(5, 0)`)).rows;
check(old.length > 0 && !('reward_rank' in old[0]), 'geri alma sonrası haftalık sıralama eski haliyle çalışır', old[0]);
await asSuper();
await db.exec(read(migDir, mig));
await db.exec(read(migDir, shortMig));
await db.exec(read(migDir, fullMig));
await asUser(s.Can);
check((await one(`select * from public.my_success_status()`)).enabled === false, 'yeniden uygulama başarılı (varsayılan kapalı)');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
