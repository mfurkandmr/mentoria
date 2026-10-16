-- Geri alma: 20261018100000_meetings
-- Zamanlanmış hatırlatma işi, görüşme tabloları ve fonksiyonları kalkar;
-- bildirim türleri eski haline döner (bu türdeki bildirimler önce silinir).
-- pg_cron uzantısı yerinde bırakılır (başka işler kullanıyor olabilir).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('meeting-reminders');
  end if;
exception
  when others then
    raise notice 'meeting-reminders işi bulunamadı: %', sqlerrm;
end;
$$;

drop function if exists public.send_meeting_reminders(timestamptz);
drop function if exists public.set_meeting_status(uuid, date, text);
drop function if exists public.meeting_occurs_on(date, boolean, date, date);
drop table if exists public.meeting_occurrences;
drop table if exists public.meeting_schedules;

delete from public.notifications where kind = 'meeting';
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request'));
