-- 20261111120000_tutoring_sessions geri alma. Talepler ve oturumlar silinir;
-- 'tutoring_request' bildirimleri de silinir (kısıt eski listeye döner).

drop function if exists public.managed_tutoring_requests(date, integer);
drop function if exists public.decide_tutoring_request(uuid, boolean, text);
drop function if exists public.teacher_tutoring_requests(date, integer);
drop function if exists public.my_tutoring_sessions();
drop function if exists public.my_tutoring_requests();
drop function if exists public.cancel_tutoring_request(uuid);
drop function if exists public.request_tutoring_session(uuid, date, text);
drop function if exists public.open_tutoring_sessions(date, integer);

drop table if exists public.tutoring_requests;
drop table if exists public.tutoring_sessions;
drop function if exists public.guard_tutoring_session();
drop function if exists public.tr_now();

delete from public.notifications where kind = 'tutoring_request';
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest', 'installment_due',
                  'timetable', 'book_request', 'coach_alert'));

-- merge_teachers: 20261111110000 sürümü.
create or replace function public.merge_teachers(p_keep uuid, p_from uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_keep public.teachers%rowtype;
  v_from public.teachers%rowtype;
begin
  select * into v_keep from public.teachers where id = p_keep for update;
  select * into v_from from public.teachers where id = p_from for update;
  if v_keep.id is null or v_from.id is null or p_keep = p_from
     or v_keep.org_id <> v_from.org_id or not public.is_org_admin(v_keep.org_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_keep.profile_id is not null or v_from.profile_id is null then
    raise exception 'TEACHER_MERGE_BAD_PAIR';
  end if;

  begin
    update public.schedule_entries set teacher_id = p_keep where teacher_id = p_from;
  exception when unique_violation then
    raise exception 'TEACHER_MERGE_CONFLICT';
  end;
  update public.class_lessons set teacher_id = p_keep where teacher_id = p_from;
  -- Müsaitlik: elle girilen varsa o kalır.
  if exists (select 1 from public.teacher_availability where teacher_id = p_keep) then
    delete from public.teacher_availability where teacher_id = p_from;
  else
    update public.teacher_availability set teacher_id = p_keep where teacher_id = p_from;
  end if;
  -- Ücret: elle girilen varsa o kalır; yoksa hesabınki kopyalanır.
  if not exists (select 1 from public.teacher_pay_rates where teacher_id = p_keep) then
    insert into public.teacher_pay_rates (teacher_id, pay_type, amount, note)
    select p_keep, pay_type, amount, note
    from public.teacher_pay_rates where teacher_id = p_from;
  end if;
  update public.finance_expenses set teacher_id = p_keep where teacher_id = p_from;
  if not exists (select 1 from public.staff_members where teacher_id = p_keep) then
    update public.staff_members set teacher_id = p_keep where teacher_id = p_from;
  end if;

  delete from public.teachers where id = p_from;
  update public.teachers
  set profile_id = v_from.profile_id,
      -- Elle girilen branşlar önce; hesabın varsayılan 'Genel'i eklenmez.
      branches = public.clean_teacher_branches(
        v_keep.branches || array_remove(v_from.branches, 'Genel'))
  where id = p_keep;
end;
$$;
revoke all on function public.merge_teachers(uuid, uuid) from public, anon;
grant execute on function public.merge_teachers(uuid, uuid) to authenticated;
