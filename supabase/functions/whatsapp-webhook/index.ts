// Meta WhatsApp webhook'u: gönderilen veli mesajlarının teslim / okundu /
// hata durumunu kuyruk satırına yazar (whatsapp_mark). Velinin cevapları
// uygulamaya alınmaz; kurumun WhatsApp Business uygulamasında kalır
// (coexistence). Gelen mesaj olayları yok sayılır.
//
// Meta panelinde (WhatsApp → Configuration → Webhook):
//   Callback URL  https://<proje>.supabase.co/functions/v1/whatsapp-webhook
//   Verify token  WHATSAPP_VERIFY_TOKEN ile aynı
//   Abonelik      messages
//
// Gerekli gizli değerler:
//   WHATSAPP_VERIFY_TOKEN  Meta'nın ilk doğrulamasında beklenen değer
//   WHATSAPP_APP_SECRET    Meta uygulama gizli anahtarı (imza doğrulama)
//
// JWT doğrulaması kapalı deploy edilir (verify_jwt = false); Meta'nın
// X-Hub-Signature-256 imzası doğrulanır, imzasız istek reddedilir.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const enc = new TextEncoder();

async function validSignature(raw: string, header: string | null, secret: string) {
  if (!header?.startsWith('sha256=')) return false;
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(raw)));
  const hex = [...mac].map((b) => b.toString(16).padStart(2, '0')).join('');
  const given = header.slice(7);
  if (given.length !== hex.length) return false;
  let diff = 0;
  for (let i = 0; i < hex.length; i++) diff |= hex.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);

  // Meta'nın abonelik doğrulaması.
  if (req.method === 'GET') {
    const token = Deno.env.get('WHATSAPP_VERIFY_TOKEN');
    if (token && url.searchParams.get('hub.mode') === 'subscribe'
        && url.searchParams.get('hub.verify_token') === token) {
      return new Response(url.searchParams.get('hub.challenge') ?? '', { status: 200 });
    }
    return new Response('forbidden', { status: 403 });
  }
  if (req.method !== 'POST') return new Response('method', { status: 405 });

  const secret = Deno.env.get('WHATSAPP_APP_SECRET');
  const raw = await req.text();
  if (!secret || !(await validSignature(raw, req.headers.get('x-hub-signature-256'), secret))) {
    return new Response('unauthorized', { status: 401 });
  }

  let payload: any;
  try {
    payload = JSON.parse(raw);
  } catch {
    return new Response('bad json', { status: 400 });
  }

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  let marked = 0;
  for (const entry of payload?.entry ?? []) {
    for (const change of entry?.changes ?? []) {
      for (const s of change?.value?.statuses ?? []) {
        if (!s?.id || !['sent', 'delivered', 'read', 'failed'].includes(s.status)) continue;
        if (s.status === 'sent') continue; // gönderimde zaten yazıldı
        const err = s.errors?.[0];
        const at = Number(s.timestamp) > 0
          ? new Date(Number(s.timestamp) * 1000).toISOString()
          : new Date().toISOString();
        const { data } = await db.rpc('whatsapp_mark', {
          p_wa_id: String(s.id),
          p_status: s.status,
          p_error: err ? `${err.code ?? ''} ${err.error_data?.details ?? err.title ?? ''}`.trim() : null,
          p_at: at,
        });
        marked += Number(data ?? 0);
      }
    }
  }
  // Meta 200 bekler; aksi hâlde aynı olayı tekrar tekrar gönderir.
  return new Response(JSON.stringify({ marked }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
