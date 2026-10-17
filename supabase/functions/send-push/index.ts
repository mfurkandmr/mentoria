// Yeni bildirim → kullanıcının telefonlarına FCM ile gönder.
//
// Çağıran: notifications tablosundaki `push_on_notification` tetikleyicisi
// (pg_net). Gövde yalnızca {"notification_id": "..."}; içerik ve cihaz
// adresleri burada service role ile okunur, dışarıdan gelen veriye güvenilmez.
//
// Gerekli gizli değerler (Supabase → Edge Functions → Secrets):
//   PUSH_WEBHOOK_SECRET   tetikleyiciyle paylaşılan parola (Vault'takiyle aynı)
//   FCM_SERVICE_ACCOUNT   Firebase → Service accounts → private key JSON'u
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından otomatik verilir.
//
// JWT doğrulaması kapalı deploy edilir (verify_jwt = false); yetki parolayla.

import { createClient } from 'jsr:@supabase/supabase-js@2';

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
    | 'review' | 'weekly_report' | 'daily_question' | 'duel' | 'duel_result';
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
    case 'weekly_report':
      return {
        title: `${s(d.child)} için haftalık Bal Raporu 🐝`,
        body: `Bu hafta ${s(d.questions)} soru çözdü, ${s(d.minutes)} dk odaklandı, ${s(d.days)} gün çalıştı.`,
        route: s(d.route) || '/parent',
      };
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

  let notificationId: string | undefined;
  try {
    notificationId = (await req.json())?.notification_id;
  } catch {
    // boş gövde
  }
  if (!notificationId) return json({ error: 'notification_id gerekli' }, 400);

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  const { data: n, error } = await db
    .from('notifications')
    .select('id, user_id, kind, data')
    .eq('id', notificationId)
    .maybeSingle<NotificationRow>();
  if (error) return json({ error: error.message }, 500);
  if (!n) return json({ sent: 0, reason: 'bildirim yok' });

  const { data: devices } = await db
    .from('device_tokens')
    .select('token')
    .eq('user_id', n.user_id);
  if (!devices?.length) return json({ sent: 0, reason: 'cihaz yok' });

  const { title, body, route } = texts(n);
  const auth = await accessToken(sa);
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  let sent = 0;
  const stale: string[] = [];
  await Promise.all(devices.map(async ({ token }) => {
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
  }));

  if (stale.length) await db.from('device_tokens').delete().in('token', stale);
  return json({ sent, removed: stale.length });
});
