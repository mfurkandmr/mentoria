// Silinen hata defteri kartlarının (ve silinen hesapların) fotoğraflarını
// depodan siler.
//
// Çağıran: pg_cron `storage-cleanup` → `kick_storage_cleanup()` (pg_net), yalnızca
// `storage_cleanup` kuyruğunda iş varken. Supabase depo satırlarının SQL ile
// silinmesine izin vermediği için silme Storage API ile burada yapılır.
//
// Gizli değerler: PUSH_WEBHOOK_SECRET (send-push ile aynı parola).
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından verilir.
// JWT doğrulaması kapalı deploy edilir (verify_jwt = false); yetki parolayla.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

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

  let removed = 0;
  // Bir çağrıda en çok 5 tur × 500 dosya.
  for (let round = 0; round < 5; round++) {
    const { data: rows, error } = await db
      .from('storage_cleanup')
      .select('bucket, path')
      .order('created_at')
      .limit(500);
    if (error) return json({ error: error.message, removed }, 500);
    if (!rows?.length) break;

    const byBucket = new Map<string, string[]>();
    for (const r of rows) {
      byBucket.set(r.bucket, [...(byBucket.get(r.bucket) ?? []), r.path]);
    }
    for (const [bucket, paths] of byBucket) {
      // Olmayan dosya hata sayılmaz (kart silinirken uygulama zaten silmiş olabilir).
      const { error: rmErr } = await db.storage.from(bucket).remove(paths);
      if (rmErr) {
        console.error('Depodan silinemedi', bucket, rmErr.message);
        return json({ error: rmErr.message, removed }, 500);
      }
      const { error: delErr } = await db
        .from('storage_cleanup')
        .delete()
        .eq('bucket', bucket)
        .in('path', paths);
      if (delErr) return json({ error: delErr.message, removed }, 500);
      removed += paths.length;
    }
  }
  return json({ removed });
});
