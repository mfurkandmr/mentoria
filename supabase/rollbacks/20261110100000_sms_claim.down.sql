-- 20261110100000_sms_claim geri alma. Önce send-sms'i eski sürümüne
-- döndürün (claim_sms çağırmayan); 'sending' kalanlar sıraya geri döner.
drop function if exists public.claim_sms(int);
update public.sms_outbox set status = 'queued' where status = 'sending';
alter table public.sms_outbox drop column if exists claimed_at;
alter table public.sms_outbox drop constraint if exists sms_outbox_status_check;
alter table public.sms_outbox
  add constraint sms_outbox_status_check
  check (status in ('queued', 'sent', 'failed'));
