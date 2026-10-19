// Yük testi için deneme öğrencileri oluşturur ve oturum anahtarlarını
// users.json'a yazar. YALNIZCA test/staging projesinde çalıştır; canlıda
// çalıştırma (gerçek kurumun koltuk sayısını ve verisini kirletir).
//
//   SUPABASE_URL=https://<staging>.supabase.co \
//   SERVICE_ROLE_KEY=... ANON_KEY=... \
//   INVITE_CODE=<koçun öğrenci davet kodu> COUNT=500 \
//   node make_users.mjs
//
// Davet kodunun kullanım hakkı ve kurumun seat_limit'i COUNT'tan büyük olmalı.
// Her öğrenciye son 30 günden birkaç soru kaydı ve 3 deneme eklenir, böylece
// ana sayfa sorguları boş tablo üzerinde ölçülmez.

import fs from 'node:fs';

const { SUPABASE_URL: BASE, SERVICE_ROLE_KEY: SR, ANON_KEY: ANON, INVITE_CODE } = process.env;
const COUNT = Number(process.env.COUNT ?? 200);
const PASSWORD = process.env.PASSWORD ?? `Yuk-${Math.random().toString(36).slice(2)}!9`;
if (!BASE || !SR || !ANON || !INVITE_CODE) {
  console.error('SUPABASE_URL, SERVICE_ROLE_KEY, ANON_KEY ve INVITE_CODE gerekli');
  process.exit(1);
}
if (/lmbykdvvxormfiaomysn/.test(BASE) && process.env.I_KNOW_THIS_IS_PROD !== '1') {
  console.error('Bu canlı proje. Yük testini staging/branch projesinde çalıştır.');
  process.exit(1);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const api = async (path, { method = 'GET', key = ANON, token, body } = {}) => {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token ?? key}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : null;
};

const subjects = await api('/rest/v1/subjects?select=id,code', { key: SR });
const tyt = subjects.filter((s) => s.code.startsWith('TYT_'));
const day = (n) => new Date(Date.now() - n * 864e5).toISOString().slice(0, 10);

const out = [];
for (let i = 0; i < COUNT; i++) {
  const email = `yuktest+${Date.now()}_${i}@example.com`;
  const user = await api('/auth/v1/admin/users', {
    method: 'POST',
    key: SR,
    body: {
      email,
      password: PASSWORD,
      email_confirm: true,
      user_metadata: { invite_code: INVITE_CODE, full_name: `Yük Test ${i + 1}`, kvkk_consent: true },
    },
  });

  // Oturum aç (Auth hız sınırına takılmamak için yavaş).
  let session;
  for (let tries = 0; ; tries++) {
    try {
      session = await api('/auth/v1/token?grant_type=password', {
        method: 'POST',
        body: { email, password: PASSWORD },
      });
      break;
    } catch (e) {
      if (tries > 5) throw e;
      await sleep(5000 * (tries + 1));
    }
  }
  const token = session.access_token;

  await api('/rest/v1/question_logs', {
    method: 'POST',
    token,
    body: Array.from({ length: 20 }, (_, k) => ({
      student_id: user.id,
      subject_id: tyt[k % tyt.length].id,
      correct: 10 + (k % 7),
      wrong: k % 4,
      blank: k % 3,
      logged_on: day(k % 28),
    })),
  });
  for (let k = 0; k < 3; k++) {
    const [exam] = await api('/rest/v1/exams', {
      method: 'POST',
      token,
      body: { student_id: user.id, exam_type: 'TYT', name: `Yük Deneme ${k + 1}`, taken_on: day(20 - k * 7) },
    });
    await api('/rest/v1/exam_subject_results', {
      method: 'POST',
      token,
      body: tyt.slice(0, 4).map((s, j) => ({
        exam_id: exam.id, subject_id: s.id, correct: 15 + k + j, wrong: 5, blank: 5,
      })),
    });
  }

  out.push({ id: user.id, token });
  if ((i + 1) % 25 === 0) console.log(`${i + 1}/${COUNT}`);
  await sleep(300);
}

fs.writeFileSync('users.json', JSON.stringify(out));
console.log(`users.json yazıldı (${out.length} öğrenci). Anahtarlar ~1 saat geçerli.`);
