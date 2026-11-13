-- Geri alma: 20261112110000_meeting_missed_whatsapp
drop function if exists public.set_meeting_status(uuid, date, text);
create or replace function public.set_meeting_status(
  p_schedule uuid, p_day date, p_status text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_s public.meeting_schedules%rowtype;
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
begin
  select * into v_s from public.meeting_schedules where id = p_schedule;
  if not found or not public.is_coach_of(v_s.student_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if p_status is not null and p_status not in ('held', 'missed', 'cancelled') then
    raise exception 'INVALID_STATUS';
  end if;
  if not public.meeting_occurs_on(v_s.first_date, v_s.repeat_weekly, v_s.until_date, p_day) then
    raise exception 'NO_MEETING_THAT_DAY';
  end if;
  -- Yapıldı / yapılmadı gelecekteki bir gün için işaretlenemez (iptal edilebilir).
  if p_status in ('held', 'missed') and p_day > v_today then
    raise exception 'MEETING_IN_FUTURE';
  end if;

  insert into public.meeting_occurrences
    (schedule_id, occurs_on, student_id, status, marked_by, marked_at)
  values (v_s.id, p_day, v_s.student_id, p_status, auth.uid(), now())
  on conflict (schedule_id, occurs_on) do update
    set status = excluded.status,
        marked_by = excluded.marked_by,
        marked_at = excluded.marked_at;
end;
$$;
revoke execute on function public.set_meeting_status(uuid, date, text) from public, anon;
grant  execute on function public.set_meeting_status(uuid, date, text) to authenticated;

alter table public.meeting_occurrences drop column if exists guardian_notified_at;
