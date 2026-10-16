-- =====================================================================
-- Telefon bildirimleri 2/2: yeni bildirim → Edge Function → FCM
--
-- notifications tablosuna kayıt düşünce (ödev, deneme sonucu, görev, koç
-- notu) `send-push` Edge Function'ı pg_net ile çağrılır. Fonksiyona yalnızca
-- bildirimin id'si gider; içerik ve cihaz adreslerini fonksiyon kendisi okur.
--
-- Ayarlar Supabase Vault'ta tutulur (koda ve migration'a gömülmez):
--   push_function_url   → https://<proje>.supabase.co/functions/v1/send-push
--   push_webhook_secret → fonksiyonla paylaşılan rastgele parola
-- Bu ikisi yoksa tetikleyici hiçbir şey yapmaz. Çağrı hata verse bile
-- bildirim kaydı ASLA engellenmez.
--
-- Geri almak için: supabase/rollbacks/20261017160000_push_webhook.down.sql
-- =====================================================================

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net;
  else
    raise notice 'pg_net yok (yerel test ortamı); tetikleyici çağrı yapmayacak';
  end if;
end;
$$;

create or replace function public.push_on_notification()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_url    text;
  v_secret text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'push_function_url';
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_url is null or v_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret),
    body := jsonb_build_object('notification_id', new.id),
    timeout_milliseconds := 5000);
  return new;
exception when others then
  -- Bildirim gönderilemese de uygulama içi bildirim kaydı kalır.
  raise warning 'push_on_notification: %', sqlerrm;
  return new;
end;
$$;
revoke execute on function public.push_on_notification() from public, anon, authenticated;

create trigger push_on_notification
  after insert on public.notifications
  for each row execute function public.push_on_notification();
