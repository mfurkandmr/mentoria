// k6 yük testi: "deneme sonucu açıklandı, herkes aynı anda uygulamayı açtı".
//
// Her iterasyon = bir öğrencinin uygulamayı açıp ana sayfaya gelmesi.
// MODE=new  → yeni akış (student_home tek RPC + bildirimler + duyurular ...)
// MODE=old  → eski akış (ana sayfa verisi 6 ayrı sorgu); karşılaştırma için.
//
// Çalıştırma (ayrıntı: README.md):
//   k6 run -e SUPABASE_URL=https://<staging>.supabase.co -e ANON_KEY=... \
//          -e USERS=users.json -e RATE=40 -e MODE=new student_open.js
//
// RATE: saniyede açılış. 40/sn × 2 dk ≈ 5.000 öğrenci.

import http from 'k6/http';
import { check, group } from 'k6';
import { SharedArray } from 'k6/data';
import { Trend } from 'k6/metrics';

const BASE = __ENV.SUPABASE_URL;
const KEY = __ENV.ANON_KEY;
const MODE = __ENV.MODE || 'new';
const RATE = Number(__ENV.RATE || 40);
const HOLD = __ENV.HOLD || '2m';

const users = new SharedArray('users', () => JSON.parse(open(__ENV.USERS || 'users.json')));

const openTime = new Trend('app_open_ms', true);

export const options = {
  scenarios: {
    deneme_aciklandi: {
      executor: 'ramping-arrival-rate',
      startRate: 1,
      timeUnit: '1s',
      preAllocatedVUs: Math.max(50, RATE * 2),
      maxVUs: Math.max(200, RATE * 10),
      stages: [
        { target: RATE, duration: '30s' }, // push'lar yayıldıkça artan açılış
        { target: RATE, duration: HOLD },
        { target: 0, duration: '15s' },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'], // %1'den az hata
    app_open_ms: ['p(95)<2500'], // açılışların %95'i 2,5 sn altında
  },
};

const isoDate = (d) => d.toISOString().slice(0, 10);

function headers(token) {
  return {
    apikey: KEY,
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

export default function () {
  const u = users[Math.floor(Math.random() * users.length)];
  const h = { headers: headers(u.token) };
  const since = new Date(Date.now() - 29 * 864e5);
  since.setUTCHours(0, 0, 0, 0);
  const t0 = Date.now();

  group('açılış', () => {
    // Uygulamanın her açılışta attığı istekler (paralel).
    const common = [
      ['GET', `${BASE}/rest/v1/profiles?select=*&id=eq.${u.id}`, null, h],
      ['GET', `${BASE}/rest/v1/notifications?select=id,kind,data,ref_id,created_at,read_at&user_id=eq.${u.id}&order=created_at.desc&limit=50`, null, h],
      ['POST', `${BASE}/rest/v1/rpc/my_announcements`, '{}', h],
      ['POST', `${BASE}/rest/v1/rpc/my_daily_question`, '{}', h],
    ];

    const home = MODE === 'old'
      ? [
          ['GET', `${BASE}/rest/v1/question_logs?select=id,correct,wrong,blank,logged_on,source,topic_id,subjects(code),topics(name)&student_id=eq.${u.id}&logged_on=gte.${isoDate(since)}&order=logged_on.desc,created_at.desc`, null, h],
          ['GET', `${BASE}/rest/v1/study_sessions?select=id,type,started_at,duration_sec,subjects(code)&student_id=eq.${u.id}&started_at=gte.${since.toISOString()}&order=started_at.desc`, null, h],
          ['GET', `${BASE}/rest/v1/goals?select=*&student_id=eq.${u.id}`, null, h],
          ['GET', `${BASE}/rest/v1/topic_progress?select=topic_id,status&student_id=eq.${u.id}`, null, h],
          ['GET', `${BASE}/rest/v1/exams?select=id,exam_type,field,name,publisher,taken_on,created_at,exam_subject_results(correct,wrong,blank,subjects(code))&student_id=eq.${u.id}&order=taken_on.desc,created_at.desc`, null, h],
          ['GET', `${BASE}/rest/v1/assignments?select=id,title,note,due_on,created_at,coach:profiles!assignments_coach_id_fkey(full_name),assignment_items(id,question_count,note,sort,done,subjects(code),topics(id,name))&student_id=eq.${u.id}&order=created_at.desc`, null, h],
        ]
      : [
          ['POST', `${BASE}/rest/v1/rpc/student_home`, JSON.stringify({
            p_student: u.id,
            p_since: isoDate(since),
            p_since_ts: since.toISOString(),
          }), h],
        ];

    const res = http.batch([...common, ...home]);
    for (const r of res) {
      check(r, { '2xx': (x) => x.status >= 200 && x.status < 300 });
    }
  });

  openTime.add(Date.now() - t0);
}
