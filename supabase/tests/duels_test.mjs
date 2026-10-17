// Arkadaş düellosu: rakip seçimi, soruların gizliliği, sunucuda puan ve
// süre, kazanan kuralı (eşitlikte hızlı olan), avatar ödülü; geri alma.
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




const A = await school('Bal Akademi', 'ADMINDU1');
const ahmet = await signUp(A.code, 'Ahmet Demir');
const can = await signUp(A.code, 'Can Kaya');
const ece = await signUp(A.code, 'Ece Tan');
const B = await school('Yıldız', 'ADMINDU2');
const zeynep = await signUp(B.code, 'Zeynep Arslan');

console.log('Cevap anahtarı havuzla aynı');
await asSuper();
const keys = new Map((await db.query(`select question_id, answer from public.practice_keys`)).rows.map((r) => [r.question_id, r.answer]));
const qdir = `${root}/assets/learn/questions`;
let total = 0, mismatch = 0;
for (const f of fs.readdirSync(qdir).filter((x) => x.endsWith('.json'))) {
  for (const q of JSON.parse(read(qdir, f))) { total++; if (keys.get(q.id) !== q.a) mismatch++; }
}
check(total === keys.size && mismatch === 0, `${total} sorunun anahtarı eşleşiyor (yoksa: python tool/questions/make_keys_sql.py)`, { total, size: keys.size, mismatch });

const answersFor = async (duel, nCorrect) => {
  await asSuper();
  const ids = (await one(`select question_ids from public.duels where id = $1`, [duel])).question_ids;
  return ids.map((id, i) => (i < nCorrect ? keys.get(id) : (keys.get(id) + 1) % 5));
};
const backdate = async (duel, col, sec) => { await asSuper(); await db.query(`update public.duels set ${col} = now() - make_interval(secs => $2) where id = $1`, [duel, sec]); };
const mine = async (who) => { await asUser(who); return (await db.query(`select * from public.my_duels()`)).rows; };

console.log('Rakipler');
await asUser(ahmet);
const ops = (await db.query(`select * from public.duel_opponents()`)).rows;
check(ops.length === 2 && ops.every((o) => [can, ece].includes(o.student_id)), 'yalnızca aynı dershanedeki diğer öğrenciler', ops);
check(ops.some((o) => o.display_name === 'Can K.'), 'ad kısaltılır', ops.map((o) => o.display_name));
await asUser(A.coach);
check((await db.query(`select * from public.duel_opponents()`)).rows.length === 0, 'koça liste yok');

console.log('Davet');
await asUser(ahmet);
const d1 = (await one(`select public.create_duel($1, 'TYT_MAT') id`, [can])).id;
ok("Ahmet Can'ı davet etti");
await expectError('başka dershaneden rakip olmaz', () => db.query(`select public.create_duel($1, 'TYT_MAT')`, [zeynep]), 'DUEL_BAD_OPPONENT');
await expectError('kendine düello olmaz', () => db.query(`select public.create_duel($1, 'TYT_MAT')`, [ahmet]), 'DUEL_BAD_OPPONENT');
await expectError('aynı ikili arasında ikinci açık düello olmaz', () => db.query(`select public.create_duel($1, 'TYT_FIZ')`, [can]), 'DUEL_ALREADY_OPEN');
await expectError('bilinmeyen ders', () => db.query(`select public.create_duel($1, 'YDT_YD')`, [ece]), 'DUEL_BAD_SUBJECT');
await asUser(A.coach);
await expectError('koç düello açamaz', () => db.query(`select public.create_duel($1, 'TYT_MAT')`, [can]), 'DUEL_NOT_ALLOWED');
await asSuper();
const inv = await one(`select data from public.notifications where user_id = $1 and kind = 'duel'`, [can]);
check(inv?.data?.from === 'Ahmet D.' && inv.data.subject === 'TYT_MAT', "Can'a davet bildirimi", inv);

console.log('Gizlilik');
await asUser(ahmet);
await expectError('düello tablosu okunamaz', () => db.query(`select * from public.duels`), 'permission denied');
await expectError('cevap anahtarı okunamaz', () => db.query(`select * from public.practice_keys`), 'permission denied');
check(!('question_ids' in (await mine(ahmet))[0]), 'listede sorular yok');
await asUser(zeynep);
await expectError('yabancı düelloyu başlatamaz', () => db.query(`select public.start_duel($1)`, [d1]), 'DUEL_NOT_FOUND');
await asUser(can);
await expectError('başlamadan bitirilemez', () => db.query(`select public.finish_duel($1, $2)`, [d1, Array(10).fill(0)]), 'DUEL_NOT_STARTED');

console.log('Oyun ve eşitlikte hız');
await asUser(ahmet);
const qs = (await one(`select public.start_duel($1) q`, [d1])).q;
check(qs.length === 10 && new Set(qs).size === 10 && qs.every((q) => q.startsWith('TYT_MAT-')), '10 farklı Matematik sorusu', qs);
const again = (await one(`select public.start_duel($1) q`, [d1])).q;
check(JSON.stringify(again) === JSON.stringify(qs), 'yeniden açınca aynı sorular, süre sıfırlanmaz');
await backdate(d1, 'challenger_started_at', 60);
let ans = await answersFor(d1, 7);
await asUser(ahmet);
check((await one(`select public.finish_duel($1, $2) w`, [d1, ans])).w === null, 'rakip bitirmeden kazanan yok');
await expectError('ikinci kez bitirilemez', () => db.query(`select public.finish_duel($1, $2)`, [d1, ans]), 'DUEL_ALREADY_FINISHED');
await expectError('eksik cevap reddedilir', () => db.query(`select public.finish_duel($1, $2)`, [d1, [1, 2]]), 'DUEL_BAD_ANSWERS');
let a = (await mine(ahmet))[0];
check(a.status === 'waiting' && a.my_correct === 7 && a.my_ms >= 59000 && a.their_correct === null, 'Ahmet: 7 doğru, rakip bekleniyor', a);
let c = (await mine(can))[0];
check(c.status === 'your_turn' && c.their_correct === null, "Can: sıra sende, Ahmet'in puanı gizli", c);
await asUser(can);
await db.query(`select public.start_duel($1)`, [d1]);
await backdate(d1, 'opponent_started_at', 90);
ans = await answersFor(d1, 7);
await asUser(can);
check((await one(`select public.finish_duel($1, $2) w`, [d1, ans])).w === ahmet, 'eşit doğruda daha hızlı bitiren (Ahmet) kazanır');
a = (await mine(ahmet))[0];
check(a.status === 'done' && a.result === 'won' && a.their_correct === 7, 'Ahmet: kazandı', a);
c = (await mine(can))[0];
check(c.result === 'lost', 'Can: kaybetti');
await asUser(ahmet);
check((await one(`select public.claim_avatar_unlocks() c`)).c.includes(44), 'kazanan uygulamayı açınca madalya açılır');
await asUser(can);
check(!(await one(`select public.claim_avatar_unlocks() c`)).c.includes(44), 'kaybedene ödül yok');
await asSuper();
const res = (await db.query(`select user_id, data from public.notifications where kind = 'duel_result' order by user_id`)).rows;
check(res.length === 2 && res.find((r) => r.user_id === ahmet).data.result === 'won' && res.find((r) => r.user_id === can).data.result === 'lost', 'iki tarafa sonuç bildirimi', res);

console.log('Çok doğru, yavaş olsa da kazanır');
await asUser(can);
const d2 = (await one(`select public.create_duel($1, 'AYT_FIZ') id`, [ahmet])).id;
await db.query(`select public.start_duel($1)`, [d2]);
await backdate(d2, 'challenger_started_at', 600);
ans = await answersFor(d2, 8);
await asUser(can); await db.query(`select public.finish_duel($1, $2)`, [d2, ans]);
await asUser(ahmet); await db.query(`select public.start_duel($1)`, [d2]);
await backdate(d2, 'opponent_started_at', 30);
ans = await answersFor(d2, 5);
await asUser(ahmet);
check((await one(`select public.finish_duel($1, $2) w`, [d2, ans])).w === can, '8 doğru 5 doğruyu yener');

console.log('Süre sınırları');
await asUser(ahmet);
const d3 = (await one(`select public.create_duel($1, 'TYT_TUR') id`, [ece])).id;
await asSuper(); await db.query(`update public.duels set expires_at = now() - interval '1 minute' where id = $1`, [d3]);
await asUser(ece);
await expectError('süresi dolan davet başlatılamaz', () => db.query(`select public.start_duel($1)`, [d3]), 'DUEL_EXPIRED');
check((await mine(ece)).find((x) => x.id === d3).status === 'expired', 'listede süresi doldu');
await asUser(ahmet);
const d4 = (await one(`select public.create_duel($1, 'TYT_TUR') id`, [ece])).id;
await db.query(`select public.start_duel($1)`, [d4]);
await backdate(d4, 'challenger_started_at', 31 * 60);
ans = await answersFor(d4, 10);
await asUser(ahmet);
await expectError('30 dakikadan sonra bitirilemez', () => db.query(`select public.finish_duel($1, $2)`, [d4, ans]), 'DUEL_TIMEOUT');

console.log('Günlük davet sınırı');
await asSuper();
await db.query(`insert into public.duels (tenant_id, challenger, opponent, subject_code, question_ids, decided_at)
  select tenant_id, $1, $2, 'TYT_MAT', array_fill('TYT_MAT-0001'::text, array[10]), now() from public.profiles, generate_series(1, 7) where id = $1`, [ahmet, ece]);
await db.query(`update public.duels set expires_at = now() - interval '1 minute' where id = $1`, [d4]);
await asUser(ahmet);
await expectError('günde en çok 10 davet', () => db.query(`select public.create_duel($1, 'TYT_MAT')`, [ece]), 'DUEL_DAILY_LIMIT');

console.log('Beş galibiyette defne tacı');
await asSuper();
await db.query(`update public.duels set winner = $1 where challenger = $1 and subject_code = 'TYT_MAT' and winner is null`, [ahmet]);
await asUser(ahmet);
const claimed = (await one(`select public.claim_avatar_unlocks() c`)).c;
check(claimed.includes(45) && !claimed.includes(46), '5+ galibiyet: defne tacı açıldı, şampiyon pelerini (10) değil', claimed);

console.log('Geri alma ve yeniden uygulama');
const name = '20261018230000_duels';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.duels') t`)).t === null, 'tablo kalktı');
check((await one(`select count(*)::int c from public.avatar_items where id in (44, 45, 46)`)).c === 0, 'ödüller kalktı');
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select count(*)::int c from public.practice_keys`)).c === total, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
