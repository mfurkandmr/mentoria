// Risk erken uyarısı (skor, koç / müdür listesi, pazartesi bildirimi) ve
// otomatik konu reçetesi (son denemelerin eksik konuları); geri alma.
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

const A = await school('Bal Akademi', 'ADMINRP1');
const ali = await signUp(A.code, 'Ali Riskli');       // hiç çalışmamış, ödev yok
const bora = await signUp(A.code, 'Bora Orta');       // net düşmüş, ödev yarım
const cem = await signUp(A.code, 'Cem İyi');          // her gün çalışmış
const yeni = await signUp(A.code, 'Yeni Gelen');      // dün kayıt oldu
await asUser(A.admin);
const coach2 = await signUp((await one(`select public.create_invite('coach') c`)).c, 'İkinci Koç');
const B = await school('Yıldız', 'ADMINRP2');
const zeynep = await signUp(B.code, 'Zeynep Uzak');

await asSuper();
await db.query(`update public.profiles set created_at = now() - interval '30 days' where id <> $1`, [yeni]);
const subj = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
const topics = (await db.query(`select id, name from public.topics where subject_id = $1 order by sort limit 4`, [subj])).rows;
const turk = (await one(`select id from public.subjects where code = 'TYT_TUR'`)).id;
const turkTopic = (await one(`select id, name from public.topics where subject_id = $1 order by sort limit 1`, [turk]));
const studied = async (student, days) => {
  for (let k = 0; k < days; k++) {
    await db.query(`insert into public.question_logs (student_id, subject_id, topic_id, logged_on, correct, wrong, blank) values ($1, $2, $3, current_date - $4::int, 10, 0, 0)`, [student, subj, topics[0].id, k]);
  }
};
await studied(bora, 4);
await studied(cem, 7);
await studied(zeynep, 0);
const exam = async (student, k, net, wrongTopics = []) => {
  const e = (await one(`insert into public.exams (student_id, exam_type, name, taken_on) values ($1, 'TYT', $2, current_date - $3::int) returning id`, [student, `D${k}`, k])).id;
  await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct, wrong) values ($1, $2, $3, 0)`, [e, subj, net]);
  for (const [t, c] of wrongTopics) await db.query(`insert into public.exam_wrong_topics (exam_id, topic_id, count) values ($1, $2, $3)`, [e, t, c]);
  return e;
};
// Bora: 60 → 52 (8 net düşüş).
await exam(bora, 20, 60);
await exam(bora, 3, 52);
// Bora: ödev 4 maddenin 2'si.
const hw = (await one(`insert into public.assignments (coach_id, student_id, title, due_on) values ($1, $2, 'Ödev', current_date - 1) returning id`, [A.coach, bora])).id;
for (const d of [true, true, false, false]) await db.query(`insert into public.assignment_items (assignment_id, subject_id, done) values ($1, $2, $3)`, [hw, subj, d]);

console.log('Skor formülü');
const score = async (s) => (await one(`select public.risk_score($1::jsonb) r`, [JSON.stringify(s)])).r;
const today = (await one(`select current_date::text d`)).d;
let r = await score({ days: 0, meetings_missed: 0, homework_total: 0, homework_done: 0, to: today });
check(r.score === 35 && r.attendance === 35, 'hiç çalışmamak 35 puan', r);
r = await score({ days: 0, meetings_missed: 5, homework_total: 4, homework_done: 0, last_net: 40, prev_net: 60, exam_on: today, to: today });
check(r.score === 100 && r.attendance === 50 && r.net === 30 && r.homework === 20, 'en kötü durum 100 (görüşme en çok 2, düşüş en çok 10 net)', r);
r = await score({ days: 7, meetings_missed: 0, homework_total: 4, homework_done: 4, last_net: 70, prev_net: 60, exam_on: today, to: today });
check(r.score === 0, 'her gün çalışan, ödevi tam, neti artan 0', r);
r = await score({ days: 7, last_net: 40, prev_net: 60, exam_on: '2026-01-01', to: today, homework_total: 0 });
check(r.net === 0, '30 günden eski denemenin düşüşü sayılmaz', r);

console.log('Koçun listesi');
const list = async (who, limit = 7) => { await asUser(who); return (await db.query(`select * from public.my_risk_list($1)`, [limit])).rows; };
let l = await list(A.coach);
const names = l.map((x) => x.full_name);
check(names.join() === 'Bora Orta,Ali Riskli', 'en riskli üstte: Bora (49), sonra hiç çalışmayan Ali (35)', names);
const b = l.find((x) => x.full_name === 'Bora Orta');
// Bora: 3 gün çalışmadı (15) + 8 net düşüş (24) + ödev yarım (10) = 49.
check(b && b.score === 49 && Number(b.net_drop) === 8 && b.homework_done === 2, 'Bora 49: devam + net + ödev', b);
check(!names.includes('Cem İyi'), 'riski düşük olan listede yok');
check(!names.includes('Yeni Gelen'), '7 günden yeni öğrenci listede yok');
check(!names.includes('Zeynep Uzak'), 'başka kurumun öğrencisi yok');
check((await list(A.coach, 1)).length === 1, 'limit çalışır');
check((await list(A.admin)).length === l.length, 'müdür kurumundakileri görür');
check((await list(coach2)).length === 0, 'öğrencisi olmayan koç boş liste');
check((await list(ali)).length === 0, 'öğrenci kimseyi göremez');
check((await list(B.coach)).every((x) => x.full_name === 'Zeynep Uzak'), 'diğer kurumun koçu yalnızca kendi öğrencisini görür');
await asUser(A.coach);
await expectError('iç fonksiyon doğrudan çağrılamaz', () => db.query(`select * from public.risk_rows(array[$1]::uuid[], now())`, [ali]), 'permission denied');

console.log('Pazartesi bildirimi');
await asSuper();
const sent = (await one(`select public.send_risk_digests() n`)).n;
const note = (await one(`select data from public.notifications where user_id = $1 and kind = 'risk_digest'`, [A.coach])).data;
check(sent === 2, 'riskli öğrencisi olan iki koça gider (Bal ve Yıldız)', sent);
check(note.count === 2 && note.names.length === 2 && note.route === '/coach', 'kaç öğrenci ve ilk adlar', note);
check((await one(`select count(*)::int c from public.notifications where user_id = $1`, [coach2])).c === 0, 'riskli öğrencisi olmayan koça gitmez');
check((await one(`select public.send_risk_digests() n`)).n === 0, 'aynı hafta ikinci kez gitmez');

console.log('Konu reçetesi');
// Ali: son 3 denemede konu 0 iki kez, konu 1 bir kez; 4. (eski) denemedeki konu 3 sayılmaz.
await exam(ali, 40, 30, [[topics[3].id, 5]]);
await exam(ali, 14, 35, [[topics[0].id, 2], [topics[1].id, 1]]);
const e2 = await exam(ali, 7, 36, [[topics[0].id, 3], [turkTopic.id, 1]]);
await exam(ali, 1, 37, [[topics[2].id, 4]]);
await asSuper();
await db.query(`insert into public.exam_answers (exam_id, subject_id, question_no, marked, correct, outcome, topic_id) values ($1, $2, 1, 'A', 'B', 'Kazanım X', $3), ($1, $2, 2, null, 'C', 'Kazanım Y', $3), ($1, $2, 3, 'D', 'D', 'Doğru yapılan', $3)`, [e2, subj, topics[0].id]);
const rx = async (who, student = ali) => { await asUser(who); return (await db.query(`select * from public.topic_prescription($1)`, [student])).rows; };
let p = await rx(A.coach);
check(p.length === 4, 'son 3 denemedeki 4 konu', p.map((x) => x.topic_name));
check(p[0].topic_id === topics[0].id && p[0].wrong === 5 && p[0].exam_count === 2 && p[0].suggested === 40, 'iki denemede tekrar eden konu başta, 5 yanlış → 40 soru', p[0]);
check(p[0].outcomes.length === 2 && p[0].outcomes.includes('Kazanım X') && p[0].outcomes.includes('Kazanım Y') && !p[0].outcomes.includes('Doğru yapılan'), 'yanlış ve boşların kazanımları gelir, doğrular gelmez', p[0].outcomes);
check(p.find((x) => x.topic_id === topics[2].id).suggested === 40 && p.find((x) => x.topic_id === topics[1].id).suggested === 15, 'soru sayısı yanlışa göre (4 → 40, 1 → 15)');
check(p.some((x) => x.subject_code === 'TYT_TUR'), 'farklı dersin konusu da gelir');
check(!p.some((x) => x.topic_id === topics[3].id), '4. (eski) deneme sayılmaz');
// Ödev verilen konu 14 gün listeden çıkar.
await asSuper();
const a2 = (await one(`insert into public.assignments (coach_id, student_id, title) values ($1, $2, 'Reçete') returning id`, [A.coach, ali])).id;
await db.query(`insert into public.assignment_items (assignment_id, subject_id, topic_id, question_count) values ($1, $2, $3, 40)`, [a2, subj, topics[0].id]);
p = await rx(A.coach);
check(!p.some((x) => x.topic_id === topics[0].id) && p.length === 3, 'ödevi verilmiş konu çıkar');
check((await rx(A.admin)).length === 3, 'müdür de çağırır');
check((await rx(A.coach, cem)).length === 0, 'yanlış kaydı olmayan öğrenci: boş');
await asUser(ali);
await expectError('öğrenci çağıramaz', () => db.query(`select * from public.topic_prescription($1)`, [ali]), 'NOT_ALLOWED');
await asUser(B.coach);
await expectError('başka kurumun koçu çağıramaz', () => db.query(`select * from public.topic_prescription($1)`, [ali]), 'NOT_ALLOWED');

console.log('Geri alma ve yeniden uygulama');
await asSuper();
for (const name of ['20261031150000_topic_prescription', '20261031140000_risk_alerts']) {
  await db.exec(read(rbDir, `${name}.down.sql`));
}
check((await one(`select count(*)::int c from pg_proc where proname in ('topic_prescription', 'my_risk_list', 'risk_rows', 'risk_score', 'send_risk_digests')`)).c === 0, 'fonksiyonlar kalktı');
check((await one(`select count(*)::int c from public.notifications where kind = 'risk_digest'`)).c === 0, 'risk bildirimleri silindi');
await expectError('risk_digest türü artık yok', () => db.query(`insert into public.notifications (user_id, kind) values ($1, 'risk_digest')`, [A.coach]));
for (const name of ['20261031140000_risk_alerts', '20261031150000_topic_prescription']) {
  await db.exec(read(migDir, `${name}.sql`));
}
ok('yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
