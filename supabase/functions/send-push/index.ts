// Yeni bildirim → kullanıcının telefonlarına ve tarayıcılarına FCM ile gönder.
//
// Çağıran: notifications tablosundaki `push_on_notification` tetikleyicisi
// (pg_net, tekli: {"notification_id": "..."}) ya da yoğun anlarda push_queue'yu
// boşaltan drain_push_queue() (toplu: {"notification_ids": [...]}, en çok 100).
// İçerik ve cihaz adresleri burada service role ile okunur, dışarıdan gelen
// veriye güvenilmez.
//
// Gerekli gizli değerler (Supabase → Edge Functions → Secrets):
//   PUSH_WEBHOOK_SECRET   tetikleyiciyle paylaşılan parola (Vault'takiyle aynı)
//   FCM_SERVICE_ACCOUNT   Firebase → Service accounts → private key JSON'u
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından otomatik verilir.
// İsteğe bağlı: WEB_APP_URL (web bildirimine dokununca açılan panel kökü;
// varsayılan https://mentoria.com.tr/app).
//
// JWT doğrulaması kapalı deploy edilir (verify_jwt = false); yetki parolayla.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const WEB_APP_URL = (Deno.env.get('WEB_APP_URL') ?? 'https://mentoria.com.tr/app').replace(/\/+$/, '');

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

const SUBJECTS: Record<string, string> = {
  TYT_TUR: 'Türkçe', TYT_MAT: 'Matematik', TYT_FIZ: 'Fizik', TYT_KIM: 'Kimya',
  TYT_BIY: 'Biyoloji', TYT_TAR: 'Tarih', TYT_COG: 'Coğrafya', TYT_FEL: 'Felsefe',
  TYT_DIN: 'Din Kültürü',
};

const AYT_SUBJECTS: Record<string, string> = {
  AYT_MAT: 'AYT Matematik', AYT_FIZ: 'AYT Fizik', AYT_KIM: 'AYT Kimya', AYT_BIY: 'AYT Biyoloji',
  AYT_EDB: 'Türk Dili ve Edebiyatı', AYT_TAR1: 'Tarih-1', AYT_COG1: 'Coğrafya-1', AYT_TAR2: 'Tarih-2',
  AYT_COG2: 'Coğrafya-2', AYT_FELG: 'Felsefe Grubu', AYT_DIN: 'AYT Din Kültürü',
};
const subjectName = (code: unknown) => SUBJECTS[String(code)] ?? AYT_SUBJECTS[String(code)] ?? '';

type NotificationRow = {
  id: string;
  user_id: string;
  kind: 'assignment' | 'exam' | 'task' | 'note' | 'deletion_request' | 'meeting'
    | 'review' | 'weekly_report' | 'daily_question' | 'duel' | 'duel_result' | 'plan'
    | 'announcement' | 'inactivity_warning' | 'risk_digest' | 'installment_due'
    | 'timetable' | 'book_request' | 'coach_alert' | 'tutoring_request';
  data: Record<string, unknown>;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

// Uygulamadaki metinlerle aynı (bkz. notification_repository.dart).
function texts(n: NotificationRow): { title: string; body: string; route: string } {
  const d = n.data ?? {};
  const s = (v: unknown) => (v == null ? '' : String(v));
  switch (n.kind) {
    case 'assignment':
      return {
        title: `Yeni ödev: ${s(d.title)}`,
        body: d.from
          ? `${s(d.from)} sana ${s(d.items)} maddelik ödev gönderdi`
          : `${s(d.items)} maddelik yeni bir ödevin var`,
        route: '/student/homework',
      };
    case 'exam':
      return {
        title: 'Deneme sonucun geldi',
        body: [s(d.name), s(d.type)].filter(Boolean).join(' · '),
        route: '/student/exams',
      };
    case 'task':
      return { title: 'Yeni görev', body: s(d.title), route: '/student' };
    case 'note':
      return { title: 'Koçundan yeni not', body: s(d.body), route: '/student' };
    case 'deletion_request':
      // Koça / kurum müdürüne; rota SQL'de alıcının paneline göre yazılır.
      return {
        title: 'Hesap silme talebi',
        body: `${s(d.student)} hesabının silinmesini istedi`,
        route: s(d.route) || '/',
      };
    case 'meeting': {
      // Öğrenciye, görüşmeye 24 saatten az kala. Saat Türkiye saatiyle.
      const at = new Date(s(d.at));
      const tz = 'Europe/Istanbul';
      const ymd = (x: Date) => x.toLocaleDateString('en-CA', { timeZone: tz });
      const tomorrow = new Date(Date.now() + 864e5);
      const day = isNaN(at.getTime())
        ? ''
        : ymd(at) === ymd(new Date())
        ? 'Bugün'
        : ymd(at) === ymd(tomorrow)
        ? 'Yarın'
        : at.toLocaleDateString('tr-TR', { weekday: 'long', timeZone: tz });
      const time = isNaN(at.getTime())
        ? ''
        : at.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', timeZone: tz });
      return {
        title: 'Görüşme hatırlatması',
        body: d.coach
          ? `${day} ${time} · ${s(d.coach)} ile görüşmen var`
          : `${day} ${time} · koçunla görüşmen var`,
        route: '/student',
      };
    }
    case 'review':
      return {
        title: 'Tekrar zamanı! 🔁',
        body: `Hata defterinde ${s(d.count)} soru seni bekliyor. Unutmadan bir daha çöz!`,
        route: '/student/mistakes',
      };
    case 'weekly_report': {
      // Tek kart: devam, ödev, net trendi (weekly_summary_data). Eski
      // bildirimlerde yalnızca soru / dakika / gün vardır.
      const net = (v: number) => v.toLocaleString('tr-TR', { maximumFractionDigits: 2 });
      const parts = d.homework_total === undefined
        ? [`Bu hafta ${s(d.questions)} soru çözdü, ${s(d.minutes)} dk odaklandı, ${s(d.days)} gün çalıştı.`]
        : [
          `${s(d.days)}/7 gün çalıştı`,
          Number(d.meetings_missed) > 0 ? `${s(d.meetings_missed)} görüşme kaçırıldı` : '',
          Number(d.homework_total) > 0
            ? `ödev %${Math.round(Number(d.homework_done) * 100 / Number(d.homework_total))}`
            : '',
          d.last_net == null
            ? ''
            : `${s(d.exam_type)} ${net(Number(d.last_net))} net` +
              (d.prev_net == null
                ? ''
                : (() => {
                  const c = Number(d.last_net) - Number(d.prev_net);
                  return ` (${c >= 0 ? '+' : '−'}${net(Math.abs(c))})`;
                })()),
        ];
      return {
        title: `${s(d.child)} için haftalık Bal Raporu 🐝`,
        body: parts.filter(Boolean).join(' · '),
        route: s(d.route) || '/parent',
      };
    }
    case 'daily_question':
      return {
        title: 'Günün Sorusu hazır ☀️',
        body: `Bugün ${SUBJECTS[s(d.subject)] ?? ''} sorusu seni bekliyor. Çöz, serini büyüt!`,
        route: '/student/daily',
      };
    case 'duel':
      return {
        title: `${s(d.from)} seni düelloya çağırdı ⚔️`,
        body: `${subjectName(d.subject)} · 10 soru. Aynı soruları çözün, kim daha iyi görelim!`,
        route: '/student/duels',
      };
    case 'duel_result':
      return {
        title: d.result === 'won'
          ? 'Düelloyu kazandın! 🏆'
          : d.result === 'lost'
          ? `Düello sonucu: ${s(d.opponent)} kazandı`
          : 'Düello berabere bitti 🤝',
        body: `${subjectName(d.subject)} düellosu sonuçlandı. Sonuca bak.`,
        route: '/student/duels',
      };
    case 'plan': {
      const w = new Date(`${s(d.week)}T12:00:00Z`);
      const week = isNaN(w.getTime())
        ? ''
        : w.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', timeZone: 'Europe/Istanbul' });
      return {
        title: 'Haftalık planın hazır 📅',
        body: `${s(d.from)} ${week} haftasının planını hazırladı. Göz at, yaptıkça işaretle!`,
        route: '/student/plan',
      };
    }
    case 'announcement':
      return {
        title: `📣 ${s(d.title)}`,
        body: s(d.body).length > 180 ? `${s(d.body).slice(0, 177)}…` : s(d.body),
        route: s(d.route) || '/',
      };
    case 'inactivity_warning':
      return {
        title: 'Hesabın yakında silinecek',
        body: `Uzun süredir giriş yapmadın. ${s(d.days) || '30'} gün içinde uygulamayı açmazsan hesabın ve verilerin silinecek.`,
        route: '/',
      };
    case 'risk_digest':
      // Koça, pazartesi sabahı: risk skoru yüksek öğrenciler.
      return {
        title: `Bu hafta ${s(d.count)} öğrenciyle konuş`,
        body: `${(Array.isArray(d.names) ? d.names : []).join(', ')}: devam, net ya da ödevde geriye düşüş var. Listeye bak.`,
        route: s(d.route) || '/coach',
      };
    case 'installment_due': {
      // Kurum müdürüne, sabah 09.00: vadesi bugün olan ödenmemiş taksitler.
      const total = Number(d.total ?? 0).toLocaleString('tr-TR', { maximumFractionDigits: 2 });
      return {
        title: `Bugün ${s(d.count)} taksitin günü geldi`,
        body: `Toplam ${total} ₺. Velilere hatırlatma gönderilsin mi?`,
        route: s(d.route) || '/admin/finance',
      };
    }
    case 'timetable':
      // Öğrenciye ve bağlı öğretmene: program yayınlandı / güncellendi.
      return {
        title: d.updated === true ? 'Ders programın güncellendi' : 'Ders programın yayınlandı',
        body: `${s(d.name)}: haftalık derslerine bak.`,
        route: s(d.route) || '/student/timetable',
      };
    case 'book_request':
      // Öğrenciye: kitap talebi onaylandı / reddedildi.
      return d.result === 'rejected'
        ? {
          title: 'Kitap talebin onaylanmadı',
          body: [`${s(d.book)} (${s(d.publisher)})`, s(d.reason)].filter(Boolean).join(': '),
          route: s(d.route) || '/student/books',
        }
        : {
          title: 'Talep ettiğin kitap eklendi',
          body: `${s(d.book)} (${s(d.publisher)}) havuzda; şimdi seçebilirsin.`,
          route: s(d.route) || '/student/books',
        };
    case 'coach_alert':
      // Koça: kurum müdürü bir öğrenci için "ilgilen" dedi.
      return {
        title: `${s(d.student)} ile ilgilenir misin?`,
        body: [s(d.from) ? `${s(d.from)} yazdı` : '', s(d.reason)].filter(Boolean).join(': '),
        route: s(d.route) || '/coach',
      };
    case 'tutoring_request': {
      // Öğretmene yeni talep; öğrenciye onay / ret (NOTLAR §87).
      const dt = new Date(`${s(d.date)}T12:00:00Z`);
      const day = isNaN(dt.getTime())
        ? ''
        : dt.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', timeZone: 'Europe/Istanbul' });
      const when = [day, s(d.time), s(d.branch)].filter(Boolean).join(' ');
      if (d.event === 'approved') {
        return { title: 'Talebin onaylandı', body: [when, s(d.teacher)].filter(Boolean).join(' · '), route: s(d.route) || '/student/study' };
      }
      if (d.event === 'rejected') {
        return { title: 'Talebin onaylanmadı', body: [when, s(d.teacher), s(d.reason)].filter(Boolean).join(' · '), route: s(d.route) || '/student/study' };
      }
      return { title: `${s(d.student)} soru çözümü istedi`, body: `${when} · Onayını bekliyor`, route: s(d.route) || '/teacher' };
    }
  }
}

// --- Google OAuth (service account JWT → erişim anahtarı), önbellekli ---
let cached: { token: string; exp: number } | null = null;

const b64url = (data: ArrayBuffer | string) => {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : new Uint8Array(data);
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;

  const tokenUri = sa.token_uri ?? 'https://oauth2.googleapis.com/token';
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const res = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claims}.${b64url(sig)}`,
    }),
  });
  if (!res.ok) throw new Error(`OAuth hatası: ${res.status}`);
  const body = await res.json();
  cached = { token: body.access_token, exp: now + (body.expires_in ?? 3600) };
  return cached.token;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const secret = Deno.env.get('PUSH_WEBHOOK_SECRET');
  if (!secret || req.headers.get('x-push-secret') !== secret) {
    return json({ error: 'unauthorized' }, 401);
  }

  const saRaw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!saRaw) return json({ error: 'FCM_SERVICE_ACCOUNT eksik' }, 500);
  const sa = JSON.parse(saRaw) as ServiceAccount;

  // Tekli: {"notification_id": "..."}; toplu (push_queue): {"notification_ids": [...]}.
  let ids: string[] = [];
  try {
    const b = await req.json();
    if (Array.isArray(b?.notification_ids)) ids = b.notification_ids.map(String);
    else if (b?.notification_id) ids = [String(b.notification_id)];
  } catch {
    // boş gövde
  }
  ids = [...new Set(ids)].slice(0, 200);
  if (!ids.length) return json({ error: 'notification_id gerekli' }, 400);

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  const { data, error } = await db
    .from('notifications')
    .select('id, user_id, kind, data')
    .in('id', ids);
  const rows = data as NotificationRow[] | null;
  if (error) return json({ error: error.message }, 500);
  if (!rows?.length) return json({ sent: 0, reason: 'bildirim yok' });

  const { data: devices, error: devErr } = await db
    .from('device_tokens')
    .select('user_id, token, platform')
    .in('user_id', [...new Set(rows.map((n) => n.user_id))]);
  if (devErr) return json({ error: devErr.message }, 500);
  if (!devices?.length) return json({ sent: 0, reason: 'cihaz yok' });

  type Device = { token: string; web: boolean };
  const tokensOf = new Map<string, Device[]>();
  for (const d of devices) {
    tokensOf.set(d.user_id, [
      ...(tokensOf.get(d.user_id) ?? []),
      { token: d.token, web: d.platform === 'web' },
    ]);
  }
  const jobs = rows.flatMap((n) =>
    (tokensOf.get(n.user_id) ?? []).map(({ token, web }) => ({ n, token, web }))
  );
  if (!jobs.length) return json({ sent: 0, reason: 'cihaz yok' });

  const auth = await accessToken(sa);
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  let sent = 0;
  const stale: string[] = [];
  const sendOne = async ({ n, token, web }: { n: NotificationRow; token: string; web: boolean }) => {
    const { title, body, route } = texts(n);
    const res = await fetch(url, {
      method: 'POST',
      headers: { Authorization: `Bearer ${auth}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: { route, kind: n.kind, notification_id: n.id },
          // Mentoria'ya özel ses. Android 8+: sesi kanal belirler (uygulama
          // açılınca oluşturulan "mentoria_bildirim", res/raw/mentoria_bildirim);
          // eski sürümler `sound` adını kullanır. iOS: dosya uygulama
          // paketinde yoksa varsayılan ses çalar.
          android: {
            priority: 'HIGH',
            notification: { channel_id: 'mentoria_bildirim', sound: 'mentoria_bildirim' },
          },
          apns: { payload: { aps: { sound: 'mentoria_bildirim.wav' } } },
          // Web (tarayıcı): dokununca panelde ilgili sayfa açılır (sitenin
          // kökündeki firebase-messaging-sw.js). Yalnızca web adreslerine.
          ...(web
            ? {
              webpush: {
                notification: { icon: `${WEB_APP_URL}/icons/Icon-192.png` },
                fcm_options: { link: `${WEB_APP_URL}${route.startsWith('/') ? route : '/'}` },
              },
            }
            : {}),
        },
      }),
    });
    if (res.ok) {
      sent++;
      return;
    }
    // Uygulama kaldırılmış / adres geçersiz: listeden çıkar.
    const err = await res.text();
    if (res.status === 404 || err.includes('UNREGISTERED') || err.includes('INVALID_ARGUMENT')) {
      stale.push(token);
    } else {
      console.error('FCM hatası', res.status, err.slice(0, 300));
    }
  };

  // Toplu gönderimde FCM'e aynı anda en fazla 25 istek.
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(25, jobs.length) }, async () => {
    while (next < jobs.length) {
      const job = jobs[next++];
      try {
        await sendOne(job);
      } catch (e) {
        console.error('FCM isteği başarısız', String(e).slice(0, 300));
      }
    }
  }));

  if (stale.length) await db.from('device_tokens').delete().in('token', stale);
  return json({ sent, removed: stale.length });
});
