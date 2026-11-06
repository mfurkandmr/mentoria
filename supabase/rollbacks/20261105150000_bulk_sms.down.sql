-- Geri alma: 20261105150000_bulk_sms
-- Toplu SMS kayıtları ve sıradaki toplu SMS'ler silinir.
drop function if exists public.my_sms_broadcasts(int);
drop function if exists public.send_bulk_sms(text, text, uuid[], uuid[], boolean);
delete from public.sms_outbox where broadcast_id is not null;
alter table public.sms_outbox drop column if exists broadcast_id;
drop table if exists public.sms_broadcasts;
