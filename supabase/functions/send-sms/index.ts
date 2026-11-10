// SMS kuyruğunu (public.sms_outbox) boşaltır: taksit hatırlatmaları, yoklama,
// sınav sonucu ve toplu SMS. Mesajlar claim_sms() ile kilitlenerek alınır.
//
// Çağıran: kick_sms() (pg_net; müdür hatırlatma gönderince ve pg_cron ile 5
// dakikada bir, sırada mesaj varsa). Mesajlar service role ile okunur.
//
// Gerekli gizli değerler (Supabase → Edge Functions → Secrets):
//   PUSH_WEBHOOK_SECRET   tetikleyiciyle paylaşılan parola (send-push ile aynı)
//   SMS_PROVIDER          şimdilik yalnızca "netgsm"; boşsa mesajlar sırada bekler
//   NETGSM_USERCODE, NETGSM_PASSWORD, NETGSM_HEADER (onaylı gönderici adı)
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından otomatik verilir.
//
// JWT doğrulaması kapalı deploy edilir (verify_jwt = false); yetki parolayla.

import { createClient } from 'jsr:@supabase/supabase-js@2';

type Sms = { id: string; phone: string; body: string };
type Result = { ok: true } | { ok: false; error: string };

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

// Netgsm REST v2: POST /sms/rest/v2/send, Basic auth, JSON gövde. Kullanıcı
// kodu ve parola adrese yazılmaz (adresler sağlayıcı ve ara sunucu
// kayıtlarında kalabilir). Yanıt {"code":"00","jobid":"..."}; 00 dışı kodlar
// hata (20 metin, 30 kimlik, 40 gönderici adı, 50/51 İYS, 70 parametre,
// 80 sınır, 85 tekrar).
async function sendNetgsm(sms: Sms): Promise<Result> {
  const user = Deno.env.get('NETGSM_USERCODE') ?? '';
  const pass = Deno.env.get('NETGSM_PASSWORD') ?? '';
  const res = await fetch('https://api.netgsm.com.tr/sms/rest/v2/send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${btoa(`${user}:${pass}`)}`,
    },
    body: JSON.stringify({
      msgheader: Deno.env.get('NETGSM_HEADER') ?? '',
      encoding: 'TR',
      messages: [{ msg: sms.body, no: sms.phone.replace(/^\+/, '') }],
    }),
  });
  const text = (await res.text()).trim();
  let code = '';
  try {
    code = String(JSON.parse(text)?.code ?? '');
  } catch {
    // JSON değilse metnin kendisi hata olarak yazılır.
  }
  return res.ok && code === '00'
    ? { ok: true }
    : { ok: false, error: `netgsm ${res.status} ${(code || text).slice(0, 80)}` };
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const secret = Deno.env.get('PUSH_WEBHOOK_SECRET');
  if (!secret || req.headers.get('x-push-secret') !== secret) {
    return json({ error: 'unauthorized' }, 401);
  }

  const provider = Deno.env.get('SMS_PROVIDER');
  if (provider !== 'netgsm') {
    // Sağlayıcı henüz bağlanmadı: mesajlar sırada kalır.
    return json({ sent: 0, reason: 'sağlayıcı yok' });
  }

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // claim_sms mesajları kilitleyip 'sending' yapar: fonksiyon aynı anda iki
  // kez çalışsa da (zamanlayıcı + yoklama) bir mesaj yalnızca birine düşer.
  const { data, error } = await db.rpc('claim_sms', { p_limit: 50 });
  if (error) return json({ error: error.message }, 500);

  let sent = 0;
  let failed = 0;
  for (const sms of (data ?? []) as Sms[]) {
    let result: Result;
    try {
      result = await sendNetgsm(sms);
    } catch (e) {
      result = { ok: false, error: String(e).slice(0, 200) };
    }
    if (result.ok) sent++;
    else failed++;
    await db
      .from('sms_outbox')
      .update(
        result.ok
          ? { status: 'sent', sent_at: new Date().toISOString(), error: null }
          : { status: 'failed', error: result.error },
      )
      .eq('id', sms.id);
  }
  return json({ sent, failed });
});
