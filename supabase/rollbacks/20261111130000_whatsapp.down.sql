-- 20261111130000_whatsapp geri alma. Önce send-whatsapp / whatsapp-webhook
-- fonksiyonlarını durdurun. 'sending' kalan WhatsApp mesajları sıraya döner
-- (eski send-sms ile SMS olarak gidebilir).
drop function if exists public.whatsapp_mark(text, text, text, timestamptz);
drop function if exists public.claim_messages(int);
drop function if exists public.disconnect_org_whatsapp();
drop function if exists public.set_org_whatsapp(text, text, text, text, text);
drop function if exists public.org_whatsapp_status();
drop table if exists public.org_whatsapp;
update public.sms_outbox set status = 'queued'
where status = 'sending' and channel = 'whatsapp';
drop index if exists public.sms_outbox_wa_message_id;
alter table public.sms_outbox
  drop column if exists channel,
  drop column if exists template,
  drop column if exists params,
  drop column if exists media_path,
  drop column if exists wa_message_id,
  drop column if exists delivered_at,
  drop column if exists read_at;

-- claim_sms: 20261110100000_sms_claim sürümü.
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

-- kick_sms: 20261105110000_finance_reminders sürümü.
create or replace function public.kick_sms()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_url    text;
  v_secret text;
begin
  if not exists (select 1 from public.sms_outbox where status = 'queued') then
    return;
  end if;
  select replace(decrypted_secret, '/send-push', '/send-sms') into v_url
  from vault.decrypted_secrets where name = 'push_function_url';
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_url is null or v_secret is null then
    return;
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000);
exception when others then
  raise warning 'kick_sms: %', sqlerrm;
end;
$$;
revoke all on function public.kick_sms() from public, anon, authenticated;
