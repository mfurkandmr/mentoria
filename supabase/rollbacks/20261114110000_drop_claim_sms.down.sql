-- 20261114110000_drop_claim_sms geri alma: 20261111130000 sürümü.

create or replace function public.claim_sms(p_limit int default 50)
returns table (id uuid, phone text, body text)
language plpgsql security definer set search_path = ''
as $$
begin
  update public.sms_outbox o
  set status = 'failed', error = 'zaman aşımı (gönderilmiş olabilir)'
  where o.status = 'sending' and o.channel = 'sms'
    and o.claimed_at < now() - interval '15 minutes';

  return query
  with due as (
    select o.id from public.sms_outbox o
    where o.status = 'queued' and o.channel = 'sms'
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

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.claim_sms(int) to service_role;
  end if;
end $$;
