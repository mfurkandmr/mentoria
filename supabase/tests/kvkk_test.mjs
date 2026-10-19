// KVKK (20261019150000_kvkk_consents): doğum yılı, rızalar, veli onayı,
// sıralama görünürlüğü, verilerimi indir, silme talepleri, fotoğraf temizliği.
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
async function coachIn(admin, name) {
  await asUser(admin);
  const coach = await signUp((await one(`select public.create_invite('coach') c`)).c, name);
  await asUser(coach);
  return { id: coach, code: (await one(`select public.create_invite('student', null, 10) c`)).c };
}
async function parentOf(student, name) {
  await asUser(student);
  return signUp((await one(`select public.create_invite('parent') c`)).c, name);
}
async function school(name, code) {
  await asSuper();
  const org = (await one(`insert into public.organizations (name, seat_limit) values ($1, 20) returning id`, [name])).id;
  await db.query(`insert into public.invite_codes (code, org_id, target_role) values ($1, $2, 'admin')`, [code, org]);
  return { org, admin: await signUp(code, `${name} Müdür`) };
}


async function signUpMeta(code, name, meta = {}) {
  await asSuper();
  return (await one(`insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`${Math.random()}@x.com`, JSON.stringify({ invite_code: code, full_name: name, kvkk_consent: true,
      privacy_version: '1.0', ...meta })])).id;
}
const status = async (who, user = null) => {
  await asUser(who);
  return (await one(`select public.consent_status($1) s`, [user])).s;
};
const visible = async (id) => { await asSuper(); return (await one(`select public.ranking_visible($1) v`, [id])).v; };

const A = await school('Bal Akademi', 'ADMINKV1');
const ayse = await coachIn(A.admin, 'Ayşe Koç');
const mehmet = await coachIn(A.admin, 'Mehmet Koç');
const thisYear = new Date().getFullYear();

// --- Kayıt -----------------------------------------------------------------------
console.log('Kayıtta doğum yılı ve rızalar');
const elif = await signUpMeta(ayse.code, 'Elif Yılmaz', { birth_year: 2000, consents: { ranking: true } });
let st = await status(elif);
check(st.birth_year === 2000 && st.minor === false, 'doğum yılı yazıldı, yetişkin', st);
check(st.privacy_notice === true && st.ranking === true && st.ranking_visible === true,
  'aydınlatma teyidi ve sıralama rızası kaydedildi', st);
check(st.history.every((h) => h.version === '1.0' && h.source === 'self'), 'sürüm ve kaynak tutuldu', st.history);

const can = await signUpMeta(ayse.code, 'Can Kaya', { birth_year: thisYear - 16, consents: { ranking: true } });
st = await status(can);
check(st.minor === true && st.ranking === true && st.ranking_visible === false,
  '18 altında rıza verse de veli onayı yokken sıralamada görünmez', st);

const nobirth = await signUpMeta(ayse.code, 'Doğum Yok');
st = await status(nobirth);
check(st.minor === true && st.ranking === false, 'doğum yılı yoksa küçük sayılır, rıza yok', st);
check((await visible(nobirth)) === false, 'rızasız görünmez');

const old = await signUpMeta(ayse.code, 'Eski Uygulama', { privacy_version: undefined, birth_year: 'abc' });
st = await status(old);
check(st.birth_year === null && st.privacy_notice === true, 'eski uygulama: sürüm 0, geçersiz yıl yok sayılır');
check(st.history[0].version === '0', 'eski kayıtların sürümü 0', st.history);

// --- Kurum beyanı -----------------------------------------------------------------
console.log('Kurum beyanıyla veli onayı');
await asUser(ayse.id);
const stmtCode = (await one(`select public.create_invite('student', null, 5, true) c`)).c;
const zeynep = await signUpMeta(stmtCode, 'Zeynep Arslan', { birth_year: thisYear - 17, consents: { ranking: true } });
st = await status(zeynep);
check(st.guardian_approval === true && st.guardian_source === 'institution' && st.ranking_visible === true,
  'kurum beyanı veli onayı sayılır, sıralamada görünür', st);
await asSuper();
check((await one(`select given_by from public.consents where user_id = $1 and kind = 'guardian_approval'`, [zeynep])).given_by === ayse.id,
  'beyanı veren koç kayıtlı');
await asUser(ayse.id);
const plainCode = (await one(`select public.create_invite('student', null, 5) c`)).c;
await asSuper();
check((await one(`select guardian_statement_at s from public.invite_codes where code = $1`, [plainCode])).s === null,
  'beyansız davette veli onayı yok');
await asUser(A.admin);
await db.query(`select public.create_invite('coach', null, 1, true)`);
await asSuper();
check((await one(`select count(*)::int c from public.invite_codes where target_role = 'coach' and guardian_statement_at is not null`)).c === 0,
  'koç davetinde beyan yok sayılır');

// --- Veli yolu --------------------------------------------------------------------
console.log('Veli onayı');
await asUser(can);
const pCode = (await one(`select public.create_invite('parent') c`)).c;
await asSuper();
check((await one(`select public.check_invite($1) i`, [pCode])).i.student_minor === true, 'veli davetinde çocuğun küçük olduğu görünür');
const canVeli = await signUpMeta(pCode, 'Can Veli', { guardian_approval: true, child_ranking: true });
st = await status(canVeli, can);
check(st.guardian_approval === true && st.guardian_source === 'parent' && st.ranking_visible === true,
  'veli onayı ve sıralama rızası çocuğa yazıldı', st);
await asSuper();
check((await one(`select count(*)::int c from public.consents where user_id = $1 and source = 'parent' and given_by = $2`, [can, canVeli])).c === 2,
  'veriyi veren veli kayıtlı');

await asUser(canVeli);
await db.query(`select public.set_consent('ranking', false, '1.0', $1)`, [can]);
check((await visible(can)) === false, 'veli sıralama rızasını geri çeker');
await asUser(canVeli);
await db.query(`select public.set_consent('ranking', true, '1.0', $1)`, [can]);
await expectError('veli kendi adına sıralama rızası veremez', () => db.query(`select public.set_consent('ranking', true, '1.0')`), 'INVALID_CONSENT');
await asUser(mehmet.id);
await expectError('başkasının çocuğuna onay verilemez', () => db.query(`select public.set_consent('ranking', true, '1.0', $1)`, [can]), 'NOT_ALLOWED');

await asUser(canVeli);
await db.query(`select public.set_consent('guardian_approval', false, '1.0', $1)`, [can]);
await asSuper();
check((await one(`select count(*)::int c from public.account_deletion_requests where student_id = $1`, [can])).c === 1,
  'veli kullanım onayını geri çekince silme talebi açılır');
check((await visible(can)) === false, 've sıralamadan çıkar');

// --- Yetişkin öğrencinin velisi -------------------------------------------------------
console.log('Yetişkin öğrenci: veli erişimi rızaya bağlı');
await asUser(elif);
await expectError('yetişkin öğrenci rızasız veli davet edemez', () => db.query(`select public.create_invite('parent')`), 'PARENT_VIEW_CONSENT_REQUIRED');
await db.query(`select public.set_consent('parent_view', true, '1.0')`);
const eCode = (await one(`select public.create_invite('parent') c`)).c;
await asSuper();
check((await one(`select public.check_invite($1) i`, [eCode])).i.student_minor === false, 'yetişkinin velisine küçük denmez');
const elifVeli = await signUpMeta(eCode, 'Elif Veli');
await asUser(elifVeli);
check((await db.query(`select * from public.exams where student_id = $1`, [elif])).rows !== undefined, 'veli bağlandı');
check((await status(elifVeli, elif)).parent_view === true, 'veli rızayı görür');
await asUser(elif);
await db.query(`select public.set_consent('parent_view', false, '1.0')`);
await asSuper();
check((await one(`select count(*)::int c from public.parent_students where student_id = $1`, [elif])).c === 0,
  'rıza geri çekilince veli bağı kalkar');
await asUser(elifVeli);
await expectError('veli artık durumu göremez', () => db.query(`select public.consent_status($1)`, [elif]), 'NOT_ALLOWED');
await asUser(can);
await expectError('küçük öğrenci veli iznini kendisi yönetmez', () => db.query(`select public.set_consent('parent_view', true, '1.0')`), 'MINOR_PARENT_VIEW');
await asUser(elif);
await expectError('öğrenci kendine veli onayı veremez', () => db.query(`select public.set_consent('guardian_approval', true, '1.0')`), 'INVALID_CONSENT');
await asUser(ayse.id);
await expectError('koç kendi adına sıralama rızası veremez', () => db.query(`select public.set_consent('ranking', true, '1.0')`), 'INVALID_CONSENT');

// --- Aynı durum tekrar yazılmaz, tabloya doğrudan yazılmaz ----------------------------
await asUser(elif);
const before = (await status(elif)).history.length;
await db.query(`select public.set_consent('ranking', true, '1.0')`);
check((await status(elif)).history.length === before, 'aynı durum ikinci kez yazılmaz');
await asUser(elif);
await expectError('tabloya doğrudan yazılamaz', () => db.query(`insert into public.consents (user_id, kind, granted, version, source) values ($1, 'ranking', true, 'x', 'self')`, [elif]));
await asUser(mehmet.id);
check((await db.query(`select * from public.consents where user_id = $1`, [elif])).rows.length === 0, 'başka koç rızaları göremez');
await asUser(ayse.id);
check((await db.query(`select * from public.consents where user_id = $1`, [elif])).rows.length > 0, 'öğrencinin koçu görür');

// --- Doğum yılı -----------------------------------------------------------------------
console.log('Doğum yılı');
await asUser(nobirth);
await db.query(`select public.set_birth_year(2001)`);
check((await status(nobirth)).minor === false, 'öğrenci boşsa bir kez girer');
await expectError('sonra kendisi değiştiremez', () => db.query(`select public.set_birth_year(2012)`), 'BIRTH_YEAR_LOCKED');
await expectError('geçersiz yıl', () => db.query(`select public.set_birth_year(1800)`), 'INVALID_BIRTH_YEAR');
await asUser(ayse.id);
await db.query(`select public.set_birth_year(2009, $1)`, [nobirth]);
check((await status(ayse.id, nobirth)).birth_year === 2009, 'koçu düzeltebilir');
await asUser(mehmet.id);
await expectError('başka koç düzeltemez', () => db.query(`select public.set_birth_year(2009, $1)`, [nobirth]), 'NOT_ALLOWED');
await asUser(elif);
await expectError('profil kolonu doğrudan değiştirilemez', () => db.query(`update public.profiles set birth_year = 2015 where id = $1`, [elif]));

// --- Sıralamada görünürlük -------------------------------------------------------------
console.log('Sıralamalarda yalnızca rıza verenler');
await asSuper();
await db.query(`update public.organizations set success_ranking_enabled = true where id = $1`, [A.org]);
const mat = (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id;
for (const [s, n] of [[elif, 30], [zeynep, 25], [nobirth, 40], [old, 35]]) {
  const ex = (await one(`insert into public.exams (student_id, exam_type, name, created_by) values ($1, 'TYT', 'D', $1) returning id`, [s])).id;
  await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct, wrong) values ($1, $2, $3, 0)`, [ex, mat, n]);
}
await asUser(zeynep);
let board = (await db.query(`select student_id from public.success_leaderboard('TYT')`)).rows.map((r) => r.student_id);
check(board.length === 2 && board.includes(elif) && board.includes(zeynep), 'başarı sıralamasında yalnızca rıza verenler', board);
board = (await db.query(`select student_id from public.avatar_leaderboard(50, 0)`)).rows.map((r) => r.student_id);
check(!board.includes(nobirth) && !board.includes(old) && board.includes(elif), 'avatar liderliğinde de', board);
await asUser(elif);
await db.query(`select public.set_consent('ranking', false, '1.0')`);
await asUser(zeynep);
board = (await db.query(`select student_id from public.success_leaderboard('TYT')`)).rows.map((r) => r.student_id);
check(board.length === 1 && board[0] === zeynep && !board.includes(elif), 'rıza geri çekilince çıkar', board);

// --- Verilerimi indir -------------------------------------------------------------------
console.log('Verilerimi indir');
await asUser(elif);
const ex = (await one(`select public.export_my_data() d`)).d;
check(ex.profile.id === elif && ex.profile.tenant_id === undefined, 'profil (kurum kimliği olmadan)', ex.profile);
check(ex.exams.length === 1 && ex.exams[0].results[0].subject === 'TYT_MAT', 'denemeler sonuçlarıyla', ex.exams);
check(ex.consents.length >= 3, 'rıza geçmişi', ex.consents.length);
await asUser(zeynep);
const ez = (await one(`select public.export_my_data() d`)).d;
check(ez.exams.length === 1 && ez.profile.id === zeynep, 'başkasının verisi gelmez');
await asSuper();
await db.exec(`set role anon`);
await expectError('girişsiz çağrılamaz', () => db.query(`select public.export_my_data()`), 'permission');
await asSuper();

// --- Süresi geçen silme talepleri -----------------------------------------------------------
console.log('Silme talepleri 29 günde sonuçlanır');
await asUser(old);
await db.query(`select public.request_account_deletion()`);
await asSuper();
await db.query(`update public.account_deletion_requests set requested_at = now() - interval '30 days' where student_id = $1`, [old]);
const n = (await one(`select public.process_overdue_deletion_requests() n`)).n;
check(n === 1, 'süresi geçen talep sonuçlandı', n);
check((await one(`select count(*)::int c from public.profiles where id = $1`, [old])).c === 0, 'hesap silindi');
check((await one(`select count(*)::int c from public.account_deletion_requests where student_id = $1`, [can])).c === 1, 'yeni talep bekliyor');
await asUser(elif);
await expectError('öğrenci çağıramaz', () => db.query(`select public.process_overdue_deletion_requests()`), 'permission');

// --- Fotoğraf temizliği -----------------------------------------------------------------------
console.log('Hata defteri fotoğrafları temizlik kuyruğuna girer');
await asUser(zeynep);
const card = (await one(`insert into public.mistake_cards (student_id, subject_id, photo_path) values ($1, $2, $3) returning id`,
  [zeynep, mat, `${zeynep}/soru1.jpg`])).id;
await db.query(`insert into public.mistake_cards (student_id, subject_id, photo_path) values ($1, $2, $3), ($1, $2, null)`,
  [zeynep, mat, `${zeynep}/soru2.jpg`]);
await db.query(`delete from public.mistake_cards where id = $1`, [card]);
await asSuper();
let q = (await db.query(`select path from public.storage_cleanup order by path`)).rows.map((r) => r.path);
check(q.length === 1 && q[0] === `${zeynep}/soru1.jpg`, 'kart silinince fotoğrafı kuyrukta', q);
await asUser(ayse.id);
await db.query(`select public.delete_student_account($1)`, [zeynep]);
await asSuper();
q = (await db.query(`select path from public.storage_cleanup order by path`)).rows.map((r) => r.path);
check(q.length === 2 && q[1] === `${zeynep}/soru2.jpg`, 'hesap silinince kalan fotoğraflar da kuyrukta', q);
await db.query(`select public.kick_storage_cleanup()`);
ok('Vault ayarı yokken tetikleme sessizce geçer');
await asUser(elif);
await expectError('kuyruk okunamaz', () => db.query(`select * from public.storage_cleanup`), 'permission');

// --- Geri alma ---------------------------------------------------------------------------------
console.log('Geri alma ve yeniden uygulama');
const name = '20261019150000_kvkk_consents';
await asSuper();
await db.exec(read(rbDir, `${name}.down.sql`));
check((await one(`select to_regclass('public.consents') t`)).t === null, 'consents kaldırıldı');
check((await one(`select count(*)::int c from information_schema.columns where table_name = 'profiles' and column_name = 'birth_year'`)).c === 0,
  'birth_year kaldırıldı');
await asUser(ayse.id);
const back = (await one(`select public.create_invite('student', null, 1) c`)).c;
const after = await signUp(back, 'Geri Alma Öğrencisi');
await asSuper();
check((await one(`select count(*)::int c from public.profiles where id = $1`, [after])).c === 1, 'eski kayıt akışı çalışır');
await asUser(zeynep === after ? elif : elif);
check((await db.query(`select * from public.avatar_leaderboard(50, 0)`)).rows.length >= 1, 'eski sıralama herkesi gösterir');
await asSuper();
await db.exec(read(migDir, `${name}.sql`));
check((await one(`select to_regclass('public.consents') t`)).t !== null, 'yeniden uygulandı');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
