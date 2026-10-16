// White label: geçiş (backfill), izolasyon, süper admin, pasif dershane ve geri alma testleri.
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';

const root = process.argv[2] ?? "../..";
const migDir = `${root}/supabase/migrations`;
const rbDir = `${root}/supabase/rollbacks`;
const all = fs.readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort();
const TENANT_FROM = '20261017100000';
const before = all.filter((f) => f < TENANT_FROM);
const tenantMigs = all.filter((f) => f >= TENANT_FROM && f < '20261018');
const read = (d, f) => fs.readFileSync(`${d}/${f}`, 'utf8');
const seed = read(`${root}/supabase`, 'seed.sql') + '\n' + read(`${root}/supabase`, 'seed_ayt_ydt_topics.sql');

const db = new PGlite();
let failures = 0;
const ok = (n) => console.log('  PASS', n);
const bad = (n, i) => { failures++; console.log('  FAIL', n, i === undefined ? '' : JSON.stringify(i)); };
const check = (cond, n, info) => (cond ? ok(n) : bad(n, info));

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
for (const f of before) await db.exec(read(migDir, f));
await db.exec(seed);
ok(`${before.length} eski migration + seed`);

const asSuper = () => db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
const asUser = (id) => db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
const asAnon = () => db.exec(`set role anon; select set_config('request.jwt.claim.sub', '', false);`);
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
const mat = async () => { await asSuper(); return (await one(`select id from public.subjects where code = 'TYT_MAT'`)).id; };

// ------------------------------------------------------------------
// 1) Dershane öncesi veriler (canlıdaki mevcut durum gibi)
// ------------------------------------------------------------------
await asSuper();
const orgA = (await one(`insert into public.organizations (name, seat_limit) values ('Bal Akademi İzmir', 10) returning id`)).id;
await db.query(`insert into public.invite_codes (code, org_id, target_role) values ('ADMINAAA', $1, 'admin')`, [orgA]);
const adminA = await signUp('ADMINAAA', 'Ayşe Müdür');
await asUser(adminA);
const coachA = await signUp((await (async () => { await asUser(adminA); return (await one(`select public.create_invite('coach') c`)).c; })()), 'Kerem Koç');
await asUser(coachA);
const stuACode = (await one(`select public.create_invite('student', null, 5) c`)).c;
const studentA = await signUp(stuACode, 'Elif Öğrenci');
await asUser(studentA);
const parentA = await signUp((await (async () => { await asUser(studentA); return (await one(`select public.create_invite('parent') c`)).c; })()), 'Veli Hanım');
const subj = await mat();
await asUser(studentA);
await db.query(`insert into public.question_logs (student_id, subject_id, correct) values ($1, $2, 10)`, [studentA, subj]);
await db.query(`insert into public.study_sessions (student_id, started_at, duration_sec) values ($1, now(), 600)`, [studentA]);
await db.query(`insert into public.goals (student_id, daily_questions) values ($1, 100)`, [studentA]);
await asUser(coachA);
const examA = (await one(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'Deneme A') returning id`, [studentA])).id;
await db.query(`insert into public.exam_subject_results (exam_id, subject_id, correct) values ($1, $2, 20)`, [examA, subj]);
await db.query(`insert into public.tasks (coach_id, student_id, title) values ($1, $2, 'Görev A')`, [coachA, studentA]);
await db.query(`insert into public.coach_notes (coach_id, student_id, body) values ($1, $2, 'Not A')`, [coachA, studentA]);
await db.query(`select public.send_assignment($1, 'Ödev A', '[{"subject_code":"TYT_MAT","question_count":20}]'::jsonb)`, [studentA]);
ok('dershane öncesi örnek veriler');

// ------------------------------------------------------------------
// 2) Dershane migration'ları ve doldurma
// ------------------------------------------------------------------
await asSuper();
for (const f of tenantMigs) await db.exec(read(migDir, f));
ok(`${tenantMigs.length} dershane migration'ı uygulandı`);

const TABLES = ['profiles', 'invite_codes', 'coach_students', 'parent_students', 'exams',
  'exam_subject_results', 'exam_wrong_topics', 'question_logs', 'topic_progress', 'study_sessions',
  'goals', 'tasks', 'coach_notes', 'assignments', 'assignment_items', 'notifications'];
const tA = await one(`select t.id, t.slug, t.primary_color from public.tenants t join public.organizations o on o.tenant_id = t.id where o.id = $1`, [orgA]);
check(tA?.slug === 'bal-akademi-izmir' && tA.primary_color === '#FFC531', 'mevcut kurum için dershane açıldı (slug, varsayılan renk)', tA);
let nulls = 0;
for (const t of TABLES) nulls += (await one(`select count(*)::int c from public.${t} where tenant_id is distinct from $1`, [tA.id])).c;
check(nulls === 0, 'mevcut tüm kayıtlara tenant_id dolduruldu');

// ------------------------------------------------------------------
// 3) Süper admin ve yeni dershane
// ------------------------------------------------------------------
await asUser(coachA);
await expectError('süper admin olmayan dershane açamaz', () => db.query(`select public.create_tenant('X Dershanesi', 'x-ders')`), 'NOT_ALLOWED');
await asSuper();
await db.query(`insert into public.platform_admins (user_id) values ($1)`, [adminA]);
await asUser(adminA);
check((await one(`select public.is_super_admin() s`)).s === true, 'is_super_admin');
const created = (await one(`select public.create_tenant('Yıldız Dershanesi', 'yildiz', '#e5484d', '#0EA5E9') r`)).r;
check(created?.admin_code?.length === 8, 'süper admin dershane açar ve müdür kodu alır', created);
await expectError('aynı slug ikinci kez alınamaz', () => db.query(`select public.create_tenant('Başka', 'yildiz')`), 'SLUG_TAKEN');
await expectError('geçersiz renk reddedilir', () => db.query(`select public.create_tenant('Renk', 'renk-test', 'kirmizi')`));
await expectError('geçersiz slug reddedilir', () => db.query(`select public.create_tenant('Slug', 'Büyük Harf')`));
const tB = created.tenant_id;
check((await one(`select primary_color c from public.tenants where id = $1`, [tB])).c === '#E5484D', 'renk büyük harfe normalize edilir');

await asAnon();
const inv = (await one(`select public.check_invite($1) r`, [created.admin_code])).r;
check(inv?.tenant?.slug === 'yildiz' && inv?.org_name === 'Yıldız Dershanesi', 'check_invite dershane markasını döndürür', inv);
const br = (await one(`select public.tenant_branding(' YILDIZ ') r`)).r;
check(br?.name === 'Yıldız Dershanesi' && br?.secondary_color === '#0EA5E9', 'tenant_branding (anon, slug ile)', br);
check((await one(`select public.tenant_branding('yok-boyle') r`)).r === null, 'olmayan slug → null');

const adminB = await signUp(created.admin_code, 'Burak Müdür');
await asUser(adminB);
const coachB = await signUp((await (async () => { await asUser(adminB); return (await one(`select public.create_invite('coach') c`)).c; })()), 'Zeynep Koç');
await asUser(coachB);
const studentB = await signUp((await one(`select public.create_invite('student', null, 5) c`)).c, 'Can Öğrenci');
await asUser(studentB);
await db.query(`insert into public.question_logs (student_id, subject_id, correct) values ($1, $2, 7)`, [studentB, subj]);
await asUser(coachB);
const examB = (await one(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'Deneme B') returning id`, [studentB])).id;
await db.query(`insert into public.tasks (coach_id, student_id, title) values ($1, $2, 'Görev B')`, [coachB, studentB]);
await db.query(`select public.send_assignment($1, 'Ödev B', '[{"subject_code":"TYT_MAT"}]'::jsonb)`, [studentB]);
await asSuper();
const bTenantOk = (await one(`select bool_and(tenant_id = $1) ok from public.profiles where id in ($2, $3, $4)`, [tB, adminB, coachB, studentB])).ok;
check(bTenantOk, 'B kullanıcıları ve verileri B dershanesinde');

// ------------------------------------------------------------------
// 4) İzolasyon: hiçbir kullanıcı öbür dershanenin satırını görmez
// ------------------------------------------------------------------
async function leak(user, otherTenant) {
  await asUser(user);
  let n = 0;
  for (const t of TABLES) n += (await one(`select count(*)::int c from public.${t} where tenant_id = $1`, [otherTenant])).c;
  n += (await one(`select count(*)::int c from public.organizations where tenant_id = $1`, [otherTenant])).c;
  return n;
}
for (const [name, u, other] of [['müdür A', adminA, tB], ['koç A', coachA, tB], ['öğrenci A', studentA, tB], ['veli A', parentA, tB],
  ['müdür B', adminB, tA.id], ['koç B', coachB, tA.id], ['öğrenci B', studentB, tA.id]]) {
  const n = await leak(u, other);
  check(n === 0, `${name} öbür dershanenin hiçbir satırını görmez`, n);
}
await asUser(adminA);
check((await one(`select count(*)::int c from public.student_summaries()`)).c === 1, 'student_summaries yalnızca kendi dershanesi (A)');
await asUser(adminB);
check((await one(`select count(*)::int c from public.tenants`)).c === 1, 'müdür B yalnızca kendi dershanesini görür');
await asUser(adminA);
check((await one(`select count(*)::int c from public.tenants`)).c === 2, 'süper admin tüm dershaneleri görür');

// Çapraz yazma denemeleri
await asUser(coachA);
await expectError('koç A, B öğrencisine deneme ekleyemez', () => db.query(`insert into public.exams (student_id, exam_type, name) values ($1, 'TYT', 'X')`, [studentB]));
await expectError('koç A, B öğrencisine görev veremez', () => db.query(`insert into public.tasks (coach_id, student_id, title) values ($1, $2, 'X')`, [coachA, studentB]));
await expectError('koç A, B öğrencisine ödev gönderemez', () => db.query(`select public.send_assignment($1, 'X', '[{"subject_code":"TYT_MAT"}]'::jsonb)`, [studentB]), 'NOT_ALLOWED');
const forged = (await one(`insert into public.tasks (coach_id, student_id, title, tenant_id) values ($1, $2, 'Sahte', $3) returning tenant_id`, [coachA, studentA, tB])).tenant_id;
check(forged === tA.id, 'istemcinin gönderdiği tenant_id yok sayılır');
await db.query(`update public.exams set tenant_id = $1 where id = $2`, [tB, examA]);
await asSuper();
check((await one(`select tenant_id from public.exams where id = $1`, [examA])).tenant_id === tA.id, 'tenant_id güncellenemez');
await expectError('profil başka dershanenin kurumuna taşınamaz', () => db.query(`update public.profiles set org_id = $1 where id = $2`, [created.org_id, studentA]), 'CROSS_TENANT');

// Dershane kaydını yalnızca süper admin değiştirir
await asUser(adminB);
const upd = await db.query(`update public.tenants set primary_color = '#000000' where id = $1 returning id`, [tB]);
check(upd.rows.length === 0, 'müdür dershane rengini değiştiremez');
await asUser(adminA);
const upd2 = await db.query(`update public.tenants set primary_color = '#123456', logo_url = 'https://x.supabase.co/storage/v1/object/public/tenant-logos/b.png' where id = $1 returning updated_at > created_at changed`, [tB]);
check(upd2.rows.length === 1, 'süper admin logo ve rengi günceller');
await expectError('logo_url yalnızca http(s)', () => db.query(`update public.tenants set logo_url = 'javascript:alert(1)' where id = $1`, [tB]));
await asUser(studentA);
await expectError('platform_admins tablosuna yazılamaz', () => db.query(`insert into public.platform_admins (user_id) values ($1)`, [studentA]));

// ------------------------------------------------------------------
// 5) Pasif dershane
// ------------------------------------------------------------------
await asUser(adminA);
await db.query(`update public.tenants set is_active = false where id = $1`, [tB]);
await asUser(studentB);
const seenWhenInactive = await one(`select (select count(*)::int from public.exams) e, (select count(*)::int from public.profiles where id = $1) p, (select bool_or(is_active) from public.tenants) a`, [studentB]);
check(seenWhenInactive.e === 0 && seenWhenInactive.p === 1 && seenWhenInactive.a === false, 'pasif dershane: veri kapalı, profil ve dershane durumu okunur', seenWhenInactive);
await asAnon();
check((await one(`select public.tenant_branding('yildiz') r`)).r === null, 'pasif dershanenin markası girişte görünmez');
await asUser(coachB);
const lateCode = await (async () => { try { return (await one(`select public.create_invite('student') c`)).c; } catch { return null; } })();
await asSuper();
const spare = 'PASIF001';
await db.query(`insert into public.invite_codes (code, org_id, target_role, coach_id) values ($1, $2, 'student', $3)`, [spare, created.org_id, coachB]);
await asAnon();
check((await one(`select public.check_invite($1) r`, [spare])).r === null, 'pasif dershanenin daveti geçersiz');
await expectError('pasif dershaneye kayıt olunamaz', () => signUp(spare, 'Geç Kalan'), 'TENANT_INACTIVE');
await asUser(adminA);
await db.query(`update public.tenants set is_active = true where id = $1`, [tB]);
await asUser(studentB);
check((await one(`select count(*)::int c from public.exams`)).c === 1, 'yeniden aktif olunca veri geri gelir');
void lateCode;

// ------------------------------------------------------------------
// 6) Eski akış: tenant_id vermeden kurum eklemek dershane açar
// ------------------------------------------------------------------
await asSuper();
const orgC = (await one(`insert into public.organizations (name) values ('Bal Akademi İzmir') returning tenant_id`)).tenant_id;
check((await one(`select slug from public.tenants where id = $1`, [orgC])).slug === 'bal-akademi-izmir-2', 'kurum eklenince benzersiz slug ile dershane açılır');

// ------------------------------------------------------------------
// 7) Geri alma ve yeniden uygulama
// ------------------------------------------------------------------
await asSuper();
for (const f of [...tenantMigs].reverse()) {
  await db.exec(read(rbDir, f.replace('.sql', '.down.sql')));
}
const gone = await one(`select to_regclass('public.tenants') t, (select count(*)::int from information_schema.columns where column_name = 'tenant_id' and table_schema = 'public') c`);
check(gone.t === null && gone.c === 0, 'geri alma: tablolar ve kolonlar kaldırıldı', gone);
await asAnon();
const oldShape = (await one(`select public.check_invite($1) r`, [spare])).r;
check(oldShape && !('tenant' in oldShape), 'geri alma: check_invite eski haline döndü', oldShape);
await asUser(coachA);
await db.query(`insert into public.tasks (coach_id, student_id, title) values ($1, $2, 'Geri alma sonrası')`, [coachA, studentA]);
ok('geri alma sonrası uygulama akışları çalışır');
await asSuper();
for (const f of tenantMigs) await db.exec(read(migDir, f));
const again = await one(`select count(*)::int c from public.tenants`);
check(again.c >= 3, 'yeniden uygulama başarılı (dershaneler kurumlardan yeniden oluştu)', again);

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
