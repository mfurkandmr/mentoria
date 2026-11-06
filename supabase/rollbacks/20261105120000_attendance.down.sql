-- Geri alma: 20261105120000_attendance
-- Yoklama kayıtları ve yoklama için girilen veli telefonları silinir.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job
    where jobname = 'attendance-retention';
  end if;
end;
$$;

drop function if exists public.purge_old_attendance(timestamptz);
drop function if exists public.send_absence_sms(date, uuid[]);
drop function if exists public.set_guardian_phone(uuid, text, text);
drop function if exists public.save_attendance(date, jsonb);
drop function if exists public.attendance_day(date);
drop function if exists public.guardian_phone_of(uuid);
drop function if exists public.can_mark_attendance(uuid);

alter table public.sms_outbox drop column if exists attendance_id;
drop table if exists public.student_guardian_phones;
drop table if exists public.attendance;
