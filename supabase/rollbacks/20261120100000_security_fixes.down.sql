-- 20261120100000_security_fixes geri alma. (Kısaltılan adlar geri gelmez.)

drop trigger if exists clamp_profile_name on public.profiles;
drop function if exists public.clamp_profile_name();

create or replace function public.request_tutoring_session(
  p_session uuid, p_date date, p_topic text default null)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_me    public.profiles%rowtype;
  v_s     public.tutoring_sessions%rowtype;
  v_t     public.teachers%rowtype;
  v_now   timestamp := public.tr_now();
  v_id    uuid;
begin
  select * into v_me from public.profiles where id = auth.uid() and role = 'student';
  if v_me.id is null or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  select * into v_s from public.tutoring_sessions where id = p_session for update;
  if v_s.id is null or not v_s.active or v_s.org_id is distinct from v_me.org_id then
    raise exception 'TUTOR_SESSION_NOT_FOUND';
  end if;
  if p_date is null or extract(isodow from p_date) <> v_s.day
     or p_date < v_now::date or p_date > v_now::date + 14
     or (p_date = v_now::date and v_s.start_time <= v_now::time) then
    raise exception 'TUTOR_BAD_DATE';
  end if;
  if exists (select 1 from public.tutoring_requests
             where session_id = p_session and student_id = v_me.id and on_date = p_date
               and status in ('pending', 'approved')) then
    raise exception 'TUTOR_ALREADY_REQUESTED';
  end if;
  if (select count(*) from public.tutoring_requests
      where student_id = v_me.id and on_date = p_date
        and status in ('pending', 'approved')) >= 3 then
    raise exception 'TUTOR_DAILY_LIMIT';
  end if;
  if (select count(*) from public.tutoring_requests
      where session_id = p_session and on_date = p_date and status = 'approved')
     >= v_s.capacity then
    raise exception 'TUTOR_SESSION_FULL';
  end if;

  insert into public.tutoring_requests
    (org_id, tenant_id, session_id, student_id, on_date, topic)
  values (v_s.org_id, v_s.tenant_id, p_session, v_me.id, p_date,
          nullif(left(trim(coalesce(p_topic, '')), 200), ''))
  returning id into v_id;

  select * into v_t from public.teachers where id = v_s.teacher_id;
  if v_t.profile_id is not null then
    insert into public.notifications (user_id, kind, ref_id, data)
    values (v_t.profile_id, 'tutoring_request', v_id, jsonb_build_object(
      'event', 'new',
      'student', v_me.full_name,
      'session_kind', v_s.kind,
      'branch', coalesce(v_s.branch, v_t.branches[1]),
      'date', p_date,
      'time', to_char(v_s.start_time, 'HH24:MI'),
      'route', '/teacher'));
  end if;
  return v_id;
end;
$$;
revoke all on function public.request_tutoring_session(uuid, date, text) from public, anon;
grant execute on function public.request_tutoring_session(uuid, date, text) to authenticated;
