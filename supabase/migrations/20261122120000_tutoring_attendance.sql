-- =====================================================================
-- Soru çözümü: geçmiş talepler ve "geldi / gelmedi" işareti (YAPILACAKLAR 17)
-- ---------------------------------------------------------------------
--  * tutoring_requests.attended: null işaretlenmedi, true geldi, false gelmedi.
--  * mark_tutoring_attendance(talep, geldi): yalnızca oturumun öğretmeni,
--    yalnızca onaylı talep ve tarihi gelmiş (bugün ya da geçmiş) oturum için.
--    geldi = null işareti geri alır.
--  * teacher_tutoring_history(gün): öğretmenin son N günkü onaylı talepleri.
--  * my_tutoring_history(gün): öğrencinin geçmiş talepleri (onaylı / reddedilen).
--
-- Geri almak için: supabase/rollbacks/20261122120000_tutoring_attendance.down.sql
-- =====================================================================

alter table public.tutoring_requests add column attended boolean;

create or replace function public.mark_tutoring_attendance(p_id uuid, p_attended boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_q public.tutoring_requests%rowtype;
  v_s public.tutoring_sessions%rowtype;
  v_t public.teachers%rowtype;
begin
  select * into v_q from public.tutoring_requests where id = p_id for update;
  select * into v_s from public.tutoring_sessions where id = v_q.session_id;
  select * into v_t from public.teachers where id = v_s.teacher_id;
  if v_q.id is null or v_t.profile_id is distinct from auth.uid()
     or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_q.status <> 'approved' then
    raise exception 'TUTOR_NOT_APPROVED';
  end if;
  if v_q.on_date > public.tr_now()::date then
    raise exception 'TUTOR_NOT_YET';
  end if;
  update public.tutoring_requests set attended = p_attended where id = p_id;
end;
$$;
revoke all on function public.mark_tutoring_attendance(uuid, boolean) from public, anon;
grant execute on function public.mark_tutoring_attendance(uuid, boolean) to authenticated;

create or replace function public.teacher_tutoring_history(p_days integer default 30)
returns table (
  id           uuid,
  session_id   uuid,
  on_date      date,
  kind         text,
  start_time   time,
  end_time     time,
  branch       text,
  capacity     smallint,
  student_name text,
  class_name   text,
  topic        text,
  status       text,
  created_at   timestamptz,
  attended     boolean
)
language sql stable security definer set search_path = ''
as $$
  select q.id, s.id, q.on_date, s.kind, s.start_time, s.end_time,
         coalesce(s.branch, t.branches[1]), s.capacity, p.full_name,
         (select c.name from public.classroom_students cs
          join public.classrooms c on c.id = cs.classroom_id
          where cs.student_id = q.student_id limit 1),
         q.topic, q.status, q.created_at, q.attended
  from public.tutoring_requests q
  join public.tutoring_sessions s on s.id = q.session_id
  join public.teachers t on t.id = s.teacher_id and t.profile_id = auth.uid()
  join public.profiles p on p.id = q.student_id
  where q.on_date between public.tr_now()::date - least(greatest(p_days, 1), 90)
                      and public.tr_now()::date
    and q.status = 'approved'
    and public.my_tenant_active()
    and (select role from public.profiles where id = auth.uid()) = 'teacher'
  order by q.on_date desc, s.start_time desc, q.created_at
$$;
revoke all on function public.teacher_tutoring_history(integer) from public, anon;
grant execute on function public.teacher_tutoring_history(integer) to authenticated;

create or replace function public.my_tutoring_history(p_days integer default 60)
returns table (
  id           uuid,
  session_id   uuid,
  on_date      date,
  kind         text,
  start_time   time,
  end_time     time,
  branch       text,
  teacher_name text,
  topic        text,
  status       text,
  reject_reason text,
  attended     boolean
)
language sql stable security definer set search_path = ''
as $$
  select q.id, s.id, q.on_date, s.kind, s.start_time, s.end_time,
         coalesce(s.branch, t.branches[1]), t.full_name, q.topic, q.status,
         q.reject_reason, q.attended
  from public.tutoring_requests q
  join public.tutoring_sessions s on s.id = q.session_id
  join public.teachers t on t.id = s.teacher_id
  where q.student_id = auth.uid()
    and q.on_date < public.tr_now()::date
    and q.on_date >= public.tr_now()::date - least(greatest(p_days, 1), 180)
    and q.status in ('approved', 'rejected')
    and public.my_tenant_active()
  order by q.on_date desc, s.start_time desc
$$;
revoke all on function public.my_tutoring_history(integer) from public, anon;
grant execute on function public.my_tutoring_history(integer) to authenticated;
