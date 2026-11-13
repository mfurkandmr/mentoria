// k6: gerçek kullanım karışımıyla kademeli yük (NOTLAR §97).
//
// Her iterasyon = bir kullanıcı işlemi (ekran açma / kayıt). Karışım:
//   %42 öğrenci ana sayfa (student_home + bildirimler + duyurular)
//   %20 soru kaydı (yazma)      %12 denemeler      %8 ders programı
//   %6  soru çözümü saatleri    %10 koç paneli (student_summaries)
//   %2  müdür kokpiti (admin_cockpit)   (+%3 ağ gecikmesi referansı)
// Oranlar bir kurumdaki kişi sayısına göre: 1 müdür, 25 koç, 1000 öğrenci.
//
// Kademe başına ayrı senaryo (her biri STEP süresince sabit hız), böylece
// özet her kademenin p95'ini ayrı verir.
//   k6 run -e ANON_KEY=... -e STEPS=10,20,40,80,160 -e STEP=2m mix.js
//   Ani yük:  -e STEPS=60 -e STEP=60s -e TAG=spike
//   Uzun:     -e STEPS=56 -e STEP=30m -e TAG=soak
import http from 'k6/http';
import { check } from 'k6';
import { SharedArray } from 'k6/data';
import { Trend, Counter } from 'k6/metrics';

const BASE = __ENV.SUPABASE_URL || 'https://iruiyvfndxhkuiwbekuf.supabase.co';
const KEY = __ENV.ANON_KEY;
const STEPS = (__ENV.STEPS || '10,20,40,80,160').split(',').map(Number);
const STEP = __ENV.STEP || '2m';
const TAG = __ENV.TAG || 'ramp';
if (BASE.includes('lmbykdvvxormfiaomysn')) throw new Error('Canlı projeye yük testi yok!');

const users = new SharedArray('users', () => JSON.parse(open('./users.json')));
const byRole = (r) => users.filter((u) => u.role === r);
const students = byRole('student');
const coaches = byRole('coach');
const admins = byRole('admin');

const actionMs = new Trend('action_ms', true);
const fails = new Counter('action_failed');

function seconds(d) {
  const m = String(d).match(/^(\d+)(s|m)$/);
  return m[2] === 'm' ? Number(m[1]) * 60 : Number(m[1]);
}

const scenarios = {};
const thresholds = { http_req_failed: ['rate<0.01'] };
let start = 0;
for (const rate of STEPS) {
  const name = `r${rate}`;
  scenarios[name] = {
    executor: 'constant-arrival-rate',
    rate,
    timeUnit: '1s',
    duration: STEP,
    startTime: `${start}s`,
    preAllocatedVUs: Math.max(20, rate * 2),
    maxVUs: Math.max(100, rate * 8),
    gracefulStop: '10s',
  };
  // Eşikler yalnızca özetin kademe kademe yazılması için.
  thresholds[`http_req_duration{scenario:${name}}`] = ['p(95)<100'];
  thresholds[`action_ms{scenario:${name}}`] = ['p(95)<100'];
  thresholds[`http_req_failed{scenario:${name}}`] = ['rate<0.01'];
  start += seconds(STEP) + 5;
}

// İşlem türüne göre süreler (özet her biri için ayrı satır yazar).
for (const a of ['ogrenci_ana_sayfa', 'soru_kaydi', 'denemeler', 'ders_programi',
  'soru_cozumu_saatleri', 'koc_paneli', 'mudur_kokpiti', 'ag_gecikmesi']) {
  thresholds[`action_ms{action:${a}}`] = ['p(95)<100'];
}

export const options = { scenarios, thresholds, summaryTrendStats: ['avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'] };

const pick = (a) => a[Math.floor(Math.random() * a.length)];
const iso = (d) => d.toISOString().slice(0, 10);
const hdr = (u) => ({
  headers: { apikey: KEY, Authorization: `Bearer ${u.token}`, 'Content-Type': 'application/json' },
});

export function setup() {
  const u = students[0];
  const r = http.get(`${BASE}/rest/v1/topics?select=id,subject_id&limit=300`, hdr(u));
  return { topics: r.status === 200 ? r.json() : [] };
}

function run(action, reqs) {
  const t0 = Date.now();
  const res = http.batch(reqs.map(([m, url, body, p]) => [m, url, body, { ...p, tags: { action } }]));
  let ok = true;
  for (const r of res) {
    ok = check(r, { '2xx': (x) => x.status >= 200 && x.status < 300 }) && ok;
  }
  actionMs.add(Date.now() - t0, { action });
  if (!ok) fails.add(1, { action });
}

export default function (data) {
  const x = Math.random();
  const today = new Date();
  if (Math.random() < 0.03) {
    // Veritabanına gitmeyen istek: yalnızca ağ + Supabase geçidi.
    run('ag_gecikmesi', [['GET', `${BASE}/auth/v1/health`, null, { headers: { apikey: KEY } }]]);
    return;
  }
  if (x < 0.42) {
    const u = pick(students);
    const h = hdr(u);
    const since = new Date(Date.now() - 29 * 864e5);
    run('ogrenci_ana_sayfa', [
      ['POST', `${BASE}/rest/v1/rpc/student_home`, JSON.stringify({
        p_student: u.id, p_since: iso(since), p_since_ts: since.toISOString(),
      }), h],
      ['GET', `${BASE}/rest/v1/notifications?select=id,kind,data,ref_id,created_at,read_at&user_id=eq.${u.id}&order=created_at.desc&limit=50`, null, h],
      ['POST', `${BASE}/rest/v1/rpc/my_announcements`, '{}', h],
    ]);
  } else if (x < 0.62) {
    const u = pick(students);
    const t = data.topics.length ? pick(data.topics) : null;
    run('soru_kaydi', [
      ['POST', `${BASE}/rest/v1/question_logs`, JSON.stringify({
        student_id: u.id, subject_id: t ? t.subject_id : 1, topic_id: t ? t.id : null,
        correct: 12, wrong: 3, blank: 1, logged_on: iso(today), source: 'yük testi',
      }), { headers: { ...hdr(u).headers, Prefer: 'return=minimal' } }],
    ]);
  } else if (x < 0.74) {
    const u = pick(students);
    run('denemeler', [
      ['GET', `${BASE}/rest/v1/exams?select=id,exam_type,field,name,publisher,taken_on,created_at,exam_subject_results(correct,wrong,blank,subjects(code))&student_id=eq.${u.id}&order=taken_on.desc,created_at.desc`, null, hdr(u)],
    ]);
  } else if (x < 0.82) {
    run('ders_programi', [['POST', `${BASE}/rest/v1/rpc/my_timetable`, '{}', hdr(pick(students))]]);
  } else if (x < 0.88) {
    run('soru_cozumu_saatleri', [
      ['POST', `${BASE}/rest/v1/rpc/open_tutoring_sessions`, JSON.stringify({ p_from: iso(today), p_days: 7 }), hdr(pick(students))],
    ]);
  } else if (x < 0.98) {
    run('koc_paneli', [['POST', `${BASE}/rest/v1/rpc/student_summaries`, '{}', hdr(pick(coaches))]]);
  } else {
    run('mudur_kokpiti', [['POST', `${BASE}/rest/v1/rpc/admin_cockpit`, '{}', hdr(pick(admins))]]);
  }
}

export function handleSummary(data) {
  const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  return {
    [`results/${TAG}-${stamp}.json`]: JSON.stringify(data, null, 1),
    stdout: '\n(özet results/ klasörüne yazıldı)\n',
  };
}
