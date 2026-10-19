// Avatar: katalog, kilit kuralları, kuşanma koruması, dershane içi sıralama,
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

const A = await school('Bal Akademi', 'ADMINAV1');
const elif = await signUp(A.code, 'Elif Yılmaz');
const can = await signUp(A.code, 'Can Kaya');
const B = await school('Yıldız Dershanesi', 'ADMINAV2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

// --- Katalog
await asUser(elif);
const cat = await one(`select count(*) filter (where category='hair')::int h, count(*) filter (where category='skin')::int s,
  count(*) filter (where category='outfit')::int o, count(*) filter (where category='accessory')::int a from public.avatar_items`);
check(cat.h === 14 && cat.s === 6 && cat.o === 12 && cat.a === 14, 'katalog: 14 saç, 6 ten, 12 kıyafet, 14 aksesuar (düello ödülleri dahil)', cat);
await expectError('öğrenci kataloğa parça ekleyemez', () => db.query(`insert into public.avatar_items (id, category, asset_name) values (99, 'hair', 'hack')`));

// --- Ücretsiz parçalarla kaydet
await db.query(`update public.profiles set avatar = '{"hair": 2, "skin": 8, "outfit": 11, "accessory": 15}' where id = $1`, [elif]);
check((await one(`select avatar->>'hair' h from public.profiles where id = $1`, [elif])).h === '2', 'öğrenci ücretsiz parçalarla avatarını kaydeder');

// --- Doğrulama
await expectError('kilitli parça kuşanılamaz', () => db.query(`update public.profiles set avatar = '{"hair": 4, "skin": 6, "outfit": 10}' where id = $1`, [elif]), 'AVATAR_ITEM_LOCKED');
await expectError('yanlış kategori reddedilir', () => db.query(`update public.profiles set avatar = '{"hair": 6}' where id = $1`, [elif]), 'AVATAR_INVALID');
await expectError('bilinmeyen anahtar reddedilir', () => db.query(`update public.profiles set avatar = '{"face_photo": 1}' where id = $1`, [elif]), 'AVATAR_INVALID');
await expectError('sayı olmayan değer reddedilir', () => db.query(`update public.profiles set avatar = '{"hair": "1"}' where id = $1`, [elif]), 'AVATAR_INVALID');
const u = await db.query(`update public.profiles set avatar = '{"hair": 1}' where id = $1 returning id`, [can]);
check(u.rows.length === 0, 'öğrenci başkasının avatarını değiştiremez');
await asUser(A.coach);
await expectError('koç avatar kaydedemez', () => db.query(`update public.profiles set avatar = '{"hair": 1}' where id = $1`, [A.coach]), 'AVATAR_STUDENTS_ONLY');

// --- Kilit açma: seri ve rozet
await asUser(elif);
let claimed = (await one(`select public.claim_avatar_unlocks() c`)).c;
check(Array.isArray(claimed) && claimed.length === 0, 'henüz hak edilmiş parça yok', claimed);
await expectError('istemci açılmış parça ekleyemez', () => db.query(`insert into public.user_unlocked_items (user_id, item_id, tenant_id) select $1, 4, tenant_id from public.profiles where id = $1`, [elif]));

const mat = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
for (const d of [1, 2, 3]) {
  await db.query(`insert into public.question_logs (student_id, subject_id, correct, logged_on) values ($1, $2, 400, current_date - $3::int)`, [elif, mat, d]);
}
claimed = (await one(`select public.claim_avatar_unlocks() c`)).c;
check(claimed.includes(4) && claimed.includes(14) && !claimed.includes(13), '3 gün seri saçı ve 1000 soru pelerini açılır, 7 gün seri açılmaz', claimed);
check((await one(`select public.claim_avatar_unlocks() c`)).c.length === 0, 'aynı parça ikinci kez açılmaz');
await db.query(`update public.profiles set avatar = '{"hair": 4, "skin": 6, "outfit": 14}' where id = $1`, [elif]);
ok('açılan parçalar kuşanılır');

// Net kuralı: koç deneme sonucu girer (TYT 60+ → gökkuşağı saç)
await asUser(A.coach);
const ex = (await one(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'Deneme') returning id`, [elif])).id;
const tur = (await one(`select id from public.subjects where code = 'TYT_TUR'`)).id;
await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct, wrong) values ($1, $2, 36, 4), ($1, $3, 30, 0)`, [ex, mat, tur]);
await asUser(elif);
claimed = (await one(`select public.claim_avatar_unlocks() c`)).c;
check(claimed.includes(5) && claimed.includes(12), 'TYT 65 net saçı ve ilk deneme rozeti kıyafeti açılır', claimed);
await asUser(can);
check((await one(`select count(*)::int c from public.user_unlocked_items`)).c === 0, 'başkasının açtığı parçalar görünmez');

// KVKK (20261019150000): sıralamada yalnızca rıza verenler görünür. Buradaki
// öğrenciler yetişkin ve rıza vermiş sayılır (rıza kuralları kvkk_test.mjs'te).
await asSuper();
await db.exec(`update public.profiles set birth_year = 2000 where role = 'student';
  insert into public.consents (user_id, kind, granted, version, source)
  select id, 'ranking', true, 'test', 'self' from public.profiles where role = 'student'`);
// --- Sıralama: aynı dershane, sayfalı, ad + baş harf
await asUser(can);
const board = (await db.query(`select * from public.avatar_leaderboard(10, 0)`)).rows;
check(board.length === 2 && board[0].display_name === 'Elif Y.' && board[0].week_questions === 1200,
  'sıralama: aynı dershane, en çok soru üstte, soyad baş harfi', board.map((r) => [r.display_name, r.week_questions]));
check(board[0].avatar?.hair === 4 && board.find((r) => r.is_me)?.display_name === 'Can K.', 'sıralama avatar JSON ve "ben" bilgisini döndürür');
check(!board.some((r) => r.display_name.startsWith('Zeynep')), 'başka dershanenin öğrencisi sıralamada yok');
const page2 = (await db.query(`select * from public.avatar_leaderboard(1, 1)`)).rows;
check(page2.length === 1 && page2[0].display_name === 'Can K.', 'sayfalama (limit/offset)');
check((await db.query(`select * from public.avatar_leaderboard(1000, 0)`)).rows.length <= 50, 'sayfa boyutu en fazla 50');
await asUser(zeynep);
const boardB = (await db.query(`select * from public.avatar_leaderboard(10, 0)`)).rows;
check(boardB.length === 1 && boardB[0].display_name === 'Zeynep A.', 'B dershanesi yalnızca kendini görür', boardB);
check((await one(`select count(*)::int c from public.profiles where avatar is not null and id <> $1`, [zeynep])).c === 0, 'B öğrencisi A avatarlarını profillerden okuyamaz');

// Pasif dershanede sıralama boş
await asSuper();
await db.query(`update public.tenants set is_active = false where id = (select tenant_id from public.profiles where id = $1)`, [zeynep]);
await asUser(zeynep);
check((await db.query(`select * from public.avatar_leaderboard(10, 0)`)).rows.length === 0, 'pasif dershanede sıralama boş');

// --- Hesap silinince avatar verisi de silinir (öğrenciyi koçu siler)
await asUser(A.coach);
await db.query(`select public.delete_student_account($1)`, [elif]);
await asSuper();
const left = await one(`select (select count(*)::int from public.user_unlocked_items where user_id = $1) u, (select count(*)::int from public.profiles where id = $1) p`, [elif]);
check(left.u === 0 && left.p === 0, 'hesap silinince avatar ve açılan parçalar silinir', left);

// --- Geri alma ve yeniden uygulama
const av = migs.find((f) => f.includes('avatars'));
await db.exec(read(rbDir, av.replace('.sql', '.down.sql')));
const gone = await one(`select to_regclass('public.avatar_items') a, to_regclass('public.user_unlocked_items') b,
  (select count(*)::int from information_schema.columns where table_name = 'profiles' and column_name = 'avatar') c`);
check(gone.a === null && gone.b === null && gone.c === 0, 'geri alma: avatar tabloları ve kolonu kaldırıldı', gone);
await asUser(can);
await db.query(`update public.profiles set full_name = 'Can Kaya' where id = $1`, [can]);
ok('geri alma sonrası profil güncelleme çalışır');
await asSuper();
await db.exec(read(migDir, av));
check((await one(`select count(*)::int c from public.avatar_items`)).c === 17, 'yeniden uygulama başarılı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
