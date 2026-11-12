-- 20261112120000_tutoring_timetable geri alma: 20261111120000 sürümleri.

create or replace function public.guard_tutoring_session()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.org_id := old.org_id;
    new.created_at := old.created_at;
  else
    new.org_id := (select org_id from public.profiles
                   where id = auth.uid() and role = 'admin');
    new.created_at := now();
  end if;
  if new.org_id is null or (auth.uid() is not null and not public.is_org_admin(new.org_id)) then
    raise exception 'TUTOR_NOT_ADMIN';
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);
  if not exists (select 1 from public.teachers
                 where id = new.teacher_id and org_id = new.org_id) then
    raise exception 'TUTOR_BAD_REF';
  end if;
  if new.room_id is not null
     and not exists (select 1 from public.rooms
                     where id = new.room_id and org_id = new.org_id) then
    raise exception 'TUTOR_BAD_REF';
  end if;
  if new.kind = 'private_lesson' then
    new.capacity := 1;
  end if;
  new.branch := nullif(trim(new.branch), '');
  new.note := nullif(trim(new.note), '');

  if new.active then
    if exists (select 1 from public.tutoring_sessions s
               where s.teacher_id = new.teacher_id and s.active
                 and s.id <> new.id and s.day = new.day
                 and s.start_time < new.end_time and new.start_time < s.end_time) then
      raise exception 'TUTOR_SESSION_OVERLAP';
    end if;
    if exists (select 1 from public.schedule_entries e
               join public.schedules sc on sc.id = e.schedule_id and sc.status = 'published'
               join public.time_slots ts on ts.id = e.time_slot_id
               where e.teacher_id = new.teacher_id and ts.day = new.day
                 and ts.start_time < new.end_time and new.start_time < ts.end_time) then
      raise exception 'TUTOR_TEACHER_BUSY';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_tutoring_session() from public, anon, authenticated;

create or replace function public.managed_tutoring_requests(p_from date, p_days integer default 14)
returns table (
  id           uuid,
  student_id   uuid,
  student_name text,
  on_date      date,
  kind         text,
  start_time   time,
  end_time     time,
  branch       text,
  teacher_name text,
  topic        text,
  status       text
)
language sql stable security definer set search_path = ''
as $$
  select q.id, q.student_id, p.full_name, q.on_date, s.kind, s.start_time, s.end_time,
         coalesce(s.branch, t.branches[1]), t.full_name, q.topic, q.status
  from public.tutoring_requests q
  join public.tutoring_sessions s on s.id = q.session_id
  join public.teachers t on t.id = s.teacher_id
  join public.profiles p on p.id = q.student_id
  where q.student_id in (select public.my_managed_students())
    and q.on_date between p_from and p_from + least(greatest(p_days, 1), 31) - 1
    and q.status <> 'cancelled'
  order by q.on_date, s.start_time, p.full_name
$$;
revoke all on function public.managed_tutoring_requests(date, integer) from public, anon;
grant execute on function public.managed_tutoring_requests(date, integer) to authenticated;
