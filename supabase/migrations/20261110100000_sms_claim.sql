-- =====================================================================
-- SMS kuyruğu: aynı mesaj iki kez gönderilmesin
-- ---------------------------------------------------------------------
-- send-sms önceden sıradaki ('queued') mesajları kilitlemeden okuyordu.
-- Fonksiyon aynı anda iki kez çalışırsa (ör. yoklama tetiklerken 5
-- dakikalık zamanlayıcı da tetiklerse) ikisi de aynı mesajları alır ve
-- veliye çift SMS gider, iki kez ücret ödenir.
--
-- Artık mesajlar claim_sms() ile alınır: satırlar `for update skip locked`
-- ile kilitlenip tek seferde 'sending' yapılır; ikinci çağrı aynı satırları
-- göremez. 15 dakikadan uzun 'sending' kalan mesaj (fonksiyon yarıda
-- kesildi) yeniden gönderilmez, 'failed' olur: gitmiş olabilir, çift SMS
-- riski yerine müdür başarısız listesinde görür.
--
-- Yalnızca service role çağırır (send-sms Edge Function).
--
-- Geri almak için: supabase/rollbacks/20261110100000_sms_claim.down.sql
-- =====================================================================

alter table public.sms_outbox drop constraint if exists sms_outbox_status_check;
alter table public.sms_outbox
  add constraint sms_outbox_status_check
  check (status in ('queued', 'sending', 'sent', 'failed'));
alter table public.sms_outbox add column if not exists claimed_at timestamptz;

create or replace function public.claim_sms(p_limit int default 50)
returns table (id uuid, phone text, body text)
language plpgsql security definer set search_path = ''
as $$
begin
  update public.sms_outbox o
  set status = 'failed', error = 'zaman aşımı (gönderilmiş olabilir)'
  where o.status = 'sending' and o.claimed_at < now() - interval '15 minutes';

  return query
  with due as (
    select o.id from public.sms_outbox o
    where o.status = 'queued'
    order by o.created_at
    limit greatest(1, least(coalesce(p_limit, 50), 200))
    for update skip locked
  )
  update public.sms_outbox o
  set status = 'sending', claimed_at = now()
  from due
  where o.id = due.id
  returning o.id, o.phone, o.body;
end;
$$;
revoke all on function public.claim_sms(int) from public, anon, authenticated;
-- Supabase'de service_role zaten varsayılan yetkiyle çalıştırabilir; yine de
-- açıkça verilir (test veritabanında bu rol yok).
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.claim_sms(int) to service_role;
  end if;
end $$;
