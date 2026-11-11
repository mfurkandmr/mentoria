// Veli mesaj kuyruğunu (public.sms_outbox, channel = 'whatsapp') kurumun
// WhatsApp Business numarasından gönderir (Meta Cloud API). Yoklama, taksit
// hatırlatma, toplu mesaj, deneme sonucu ve ödev bildirimi buradan gider.
//
// Çağıran: kick_sms() (pg_net; mesaj kuyruğa yazılınca ve pg_cron ile 5
// dakikada bir). Mesajlar claim_messages() ile kilitlenerek alınır (çift
// gönderim yok); yalnızca WhatsApp'ı bağlı kurumların mesajları gelir.
//
// Şablon: Meta, veli son 24 saatte yazmadıysa yalnızca onaylı şablonla
// mesaj gönderilmesine izin verir.
//   * Satırda `template` varsa o şablon, `params` sırayla {{1}}, {{2}}…
//   * Yoksa kurumun genel şablonu (varsayılan `kurum_bilgilendirme`):
//     {{1}} = mesaj metni, {{2}} = kurum adı. Metin Meta'ya bir kez
//     onaylatılır (docs/WHATSAPP_KURULUM.md).
//   * `media_path` ('kova/yol/dosya.pdf') varsa şablonun belge başlığına
//     7 günlük imzalı Storage adresiyle eklenir.
//
// Gerekli gizli değerler (Supabase → Edge Functions → Secrets):
//   PUSH_WEBHOOK_SECRET   tetikleyiciyle paylaşılan parola (send-push ile aynı)
// Kurumun erişim anahtarı veritabanında (org_whatsapp), istemciye hiç gitmez.
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından verilir.
//
// JWT doğrulaması kapalı deploy edilir (verify_jwt = false); yetki parolayla.

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

const GRAPH = 'https://graph.facebook.com/v21.0';

type Msg = {
  id: string;
  phone: string;
  body: string;
  template: string | null;
  params: unknown;
  media_path: string | null;
  org_name: string;
  phone_number_id: string;
  access_token: string;
  default_template: string;
  template_lang: string;
};
type Result = { ok: true; waId: string } | { ok: false; error: string };

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

// Meta şablon değişkeninde satır sonu, sekme ve 4'ten fazla boşluk kabul
// etmez; en çok 1024 karakter.
export function cleanParam(v: unknown): string {
  return String(v ?? '')
    .replace(/[\r\n\t]+/g, ' · ')
    .replace(/ {4,}/g, '   ')
    .trim()
    .slice(0, 1024) || '-';
}

// Türkiye numarası: +90 5xx… → 905xx… (Cloud API başında + istemez).
export function waPhone(phone: string): string {
  const d = phone.replace(/\D/g, '');
  if (d.startsWith('90')) return d;
  if (d.startsWith('0')) return `9${d}`;
  if (d.length === 10 && d.startsWith('5')) return `90${d}`;
  return d;
}

async function mediaLink(db: SupabaseClient, path: string): Promise<string | null> {
  const slash = path.indexOf('/');
  if (slash <= 0) return null;
  const { data } = await db.storage
    .from(path.slice(0, slash))
    .createSignedUrl(path.slice(slash + 1), 7 * 24 * 3600);
  return data?.signedUrl ?? null;
}

async function send(db: SupabaseClient, m: Msg): Promise<Result> {
  const params = m.template
    ? (Array.isArray(m.params) ? m.params : []).map(cleanParam)
    : [cleanParam(m.body), cleanParam(m.org_name)];
  const components: unknown[] = [];
  if (m.media_path) {
    const link = await mediaLink(db, m.media_path);
    if (!link) return { ok: false, error: 'ek dosya bulunamadı' };
    components.push({
      type: 'header',
      parameters: [{
        type: 'document',
        document: {
          link,
          // Velinin göreceği ad; ödevlerde kimlik yerine "Odev.pdf".
          filename: m.media_path.startsWith('homework/')
            ? 'Odev.pdf'
            : m.media_path.split('/').pop() ?? 'dosya.pdf',
        },
      }],
    });
  }
  if (params.length) {
    components.push({
      type: 'body',
      parameters: params.map((text) => ({ type: 'text', text })),
    });
  }
  const res = await fetch(`${GRAPH}/${m.phone_number_id}/messages`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${m.access_token}`,
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to: waPhone(m.phone),
      type: 'template',
      template: {
        name: m.template ?? m.default_template,
        language: { code: m.template_lang },
        components,
      },
    }),
  });
  let out: any = null;
  try {
    out = await res.json();
  } catch {
    // Gövde JSON değil.
  }
  const waId = out?.messages?.[0]?.id;
  if (res.ok && waId) return { ok: true, waId };
  const e = out?.error;
  return {
    ok: false,
    error: `whatsapp ${res.status} ${e?.code ?? ''} ${e?.error_data?.details ?? e?.message ?? ''}`
      .trim()
      .slice(0, 200),
  };
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const secret = Deno.env.get('PUSH_WEBHOOK_SECRET');
  if (!secret || req.headers.get('x-push-secret') !== secret) {
    return json({ error: 'unauthorized' }, 401);
  }

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  const { data, error } = await db.rpc('claim_messages', { p_limit: 50 });
  if (error) return json({ error: error.message }, 500);

  let sent = 0;
  let failed = 0;
  for (const m of (data ?? []) as Msg[]) {
    let r: Result;
    try {
      r = await send(db, m);
    } catch (e) {
      r = { ok: false, error: String(e).slice(0, 200) };
    }
    if (r.ok) sent++;
    else failed++;
    await db
      .from('sms_outbox')
      .update(
        r.ok
          ? { status: 'sent', sent_at: new Date().toISOString(), error: null, wa_message_id: r.waId }
          : { status: 'failed', error: r.error },
      )
      .eq('id', m.id);
  }
  return json({ sent, failed });
});
