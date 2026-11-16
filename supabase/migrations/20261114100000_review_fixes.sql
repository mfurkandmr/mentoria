-- İnceleme düzeltmeleri (NOTLAR §100):
--  * decide_tutoring_request: geçmiş tarih, pasif oturum, pasif kurum reddedilir.
--  * my_tutoring_sessions / teacher_tutoring_requests: öğretmen rolü + kurum aktifliği.
--  * Öğretmen daveti ve kaydı: lisans süresi kontrolü.
--  * Soru çözümü talepleri için saklama süresi (retention_settings.tutoring_keep).
-- Geri almak için: supabase/rollbacks/20261114100000_review_fixes.down.sql

create or replace function public.decide_tutoring_request(
  p_id uuid, p_approve boolean, p_reason text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_q public.tutoring_requests%rowtype;
  v_s public.tutoring_sessions%rowtype;
  v_t public.teachers%rowtype;
begin
  select * into v_q from public.tutoring_requests where id = p_id for update;
  select * into v_s from public.tutoring_sessions where id = v_q.session_id for update;
  select * into v_t from public.teachers where id = v_s.teacher_id;
  if v_q.id is null or v_t.profile_id is distinct from auth.uid()
     or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_q.status <> 'pending' then
    raise exception 'TUTOR_ALREADY_DECIDED';
  end if;
  -- Geçmiş tarihli ya da kaldırılmış oturuma ait talep onaylanamaz.
  if p_approve and (v_q.on_date < public.tr_now()::date or not v_s.active) then
    raise exception 'TUTOR_BAD_DATE';
  end if;
  if p_approve and (select count(*) from public.tutoring_requests
                    where session_id = v_s.id and on_date = v_q.on_date
                      and status = 'approved') >= v_s.capacity then
    raise exception 'TUTOR_SESSION_FULL';
  end if;

  update public.tutoring_requests
  set status = case when p_approve then 'approved' else 'rejected' end,
      reject_reason = case when p_approve then null
                           else nullif(left(trim(coalesce(p_reason, '')), 200), '') end,
      decided_by = auth.uid(),
      decided_at = now()
  where id = p_id;

  insert into public.notifications (user_id, kind, ref_id, data)
  values (v_q.student_id, 'tutoring_request', p_id, jsonb_build_object(
    'event', case when p_approve then 'approved' else 'rejected' end,
    'teacher', v_t.full_name,
    'session_kind', v_s.kind,
    'branch', coalesce(v_s.branch, v_t.branches[1]),
    'date', v_q.on_date,
    'time', to_char(v_s.start_time, 'HH24:MI'),
    'reason', case when p_approve then null
                   else nullif(left(trim(coalesce(p_reason, '')), 200), '') end,
    'route', '/student/study'));
end;
$$;
revoke all on function public.decide_tutoring_request(uuid, boolean, text) from public, anon;
grant execute on function public.decide_tutoring_request(uuid, boolean, text) to authenticated;

create or replace function public.my_tutoring_sessions()
returns table (
  id         uuid,
  kind       text,
  day        smallint,
  start_time time,
  end_time   time,
  capacity   smallint,
  branch     text,
  room_name  text
)
language sql stable security definer set search_path = ''
as $$
  select s.id, s.kind, s.day, s.start_time, s.end_time, s.capacity,
         coalesce(s.branch, t.branches[1]), r.name
  from public.tutoring_sessions s
  join public.teachers t on t.id = s.teacher_id and t.profile_id = auth.uid()
  left join public.rooms r on r.id = s.room_id
  where s.active
    and public.my_tenant_active()
    and (select role from public.profiles where id = auth.uid()) = 'teacher'
  order by s.day, s.start_time
$$;
revoke all on function public.my_tutoring_sessions() from public, anon;
grant execute on function public.my_tutoring_sessions() to authenticated;

create or replace function public.teacher_tutoring_requests(p_from date, p_days integer default 14)
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
  created_at   timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select q.id, s.id, q.on_date, s.kind, s.start_time, s.end_time,
         coalesce(s.branch, t.branches[1]), s.capacity, p.full_name,
         (select c.name from public.classroom_students cs
          join public.classrooms c on c.id = cs.classroom_id
          where cs.student_id = q.student_id limit 1),
         q.topic, q.status, q.created_at
  from public.tutoring_requests q
  join public.tutoring_sessions s on s.id = q.session_id
  join public.teachers t on t.id = s.teacher_id and t.profile_id = auth.uid()
  join public.profiles p on p.id = q.student_id
  where q.on_date between p_from and p_from + least(greatest(p_days, 1), 31) - 1
    and q.status <> 'cancelled'
    and public.my_tenant_active()
    and (select role from public.profiles where id = auth.uid()) = 'teacher'
  order by q.on_date, s.start_time, q.created_at
$$;
revoke all on function public.teacher_tutoring_requests(date, integer) from public, anon;
grant execute on function public.teacher_tutoring_requests(date, integer) to authenticated;

create or replace function public.create_invite(
  p_target_role public.user_role,
  p_coach uuid default null,
  p_max_uses integer default 1,
  p_guardian_statement boolean default false
) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_me      public.profiles%rowtype;
  v_code    text;
  v_coach   uuid;
  v_student uuid;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if v_me.role = 'admin' and p_target_role in ('coach', 'teacher') then
    null;
  elsif v_me.role = 'admin' and p_target_role = 'student' then
    if not exists (
      select 1 from public.profiles
      where id = p_coach and role = 'coach' and org_id = v_me.org_id
    ) then
      raise exception 'COACH_NOT_IN_ORG';
    end if;
    v_coach := p_coach;
  elsif v_me.role = 'coach' and p_target_role = 'student' then
    v_coach := v_me.id;
  elsif v_me.role = 'student' and p_target_role = 'parent' then
    v_student := v_me.id;
    -- Yetişkin öğrenci velisini ancak açık rızasıyla ekler.
    if not public.is_minor(v_me.id) and not public.has_consent(v_me.id, 'parent_view') then
      raise exception 'PARENT_VIEW_CONSENT_REQUIRED';
    end if;
  else
    raise exception 'NOT_ALLOWED';
  end if;

  if p_target_role = 'teacher' then
    if not exists (select 1 from public.organizations
                   where id = v_me.org_id and is_active) then
      raise exception 'ORG_INACTIVE';
    end if;
    if exists (select 1 from public.organizations
               where id = v_me.org_id and license_expires_at <= now()) then
      raise exception 'LICENSE_EXPIRED';
    end if;
  end if;
  if p_target_role = 'student' then
    if not exists (select 1 from public.organizations
                   where id = v_me.org_id and is_active) then
      raise exception 'ORG_INACTIVE';
    end if;
    if not exists (select 1 from public.organizations
                   where id = v_me.org_id and credit_balance > 0) then
      raise exception 'NO_CREDITS';
    end if;
  end if;

  loop
    v_code := public.random_code(8);
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;

  insert into public.invite_codes
    (code, org_id, target_role, coach_id, student_id, created_by, max_uses, expires_at,
     guardian_statement_at)
  values
    (v_code, v_me.org_id, p_target_role, v_coach, v_student, v_me.id,
     greatest(1, least(p_max_uses, 200)),
     now() + case when p_target_role = 'parent'
                  then interval '30 days' else interval '14 days' end,
     case when p_target_role = 'student' and p_guardian_statement then now() end);

  return v_code;
end;
$$;

create or replace function public.apply_signup_invite(p_user_id uuid, p_meta jsonb, p_apply boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_code      text := upper(trim(p_meta ->> 'invite_code'));
  v_name      text := trim(p_meta ->> 'full_name');
  v_version   text := coalesce(nullif(trim(p_meta ->> 'privacy_version'), ''), '0');
  v_number    text := nullif(regexp_replace(upper(coalesce(p_meta ->> 'student_number', '')), '\s', '', 'g'), '');
  v_birth     int;
  v_grade     smallint;
  v_invite    public.invite_codes%rowtype;
  v_org_code  boolean := false;
  v_org       public.organizations%rowtype;
  v_expected  public.expected_students%rowtype;
  v_source    text;
  v_flag      text;
  v_attempted text;
  v_store     text;
  v_branches  text[];
begin
  if v_code is null or v_code = '' then
    raise exception 'INVITE_REQUIRED';
  end if;
  if v_name is null or length(v_name) < 3 then
    raise exception 'NAME_REQUIRED';
  end if;
  if (p_meta ->> 'kvkk_consent') is distinct from 'true' then
    raise exception 'KVKK_REQUIRED';
  end if;

  begin
    v_birth := nullif(p_meta ->> 'birth_year', '')::int;
  exception when others then
    v_birth := null;
  end;
  if v_birth is not null
     and (v_birth < 1940 or v_birth > extract(year from current_date)::int - 10) then
    v_birth := null;
  end if;

  -- Sınıf seviyesi: 9, 10, 11, 12 (12 = 12. sınıf ve mezun). Geçersizse boş.
  begin
    v_grade := nullif(p_meta ->> 'grade_level', '')::smallint;
  exception when others then
    v_grade := null;
  end;
  if v_grade is not null and v_grade not between 9 and 12 then
    v_grade := null;
  end if;

  select * into v_invite
  from public.invite_codes
  where code = v_code
  for update;

  if found then
    if v_invite.expires_at <= now() or v_invite.used_count >= v_invite.max_uses then
      raise exception 'INVITE_INVALID';
    end if;
  else
    select * into v_org from public.organizations where invite_code = v_code;
    if not found then
      raise exception 'INVITE_INVALID';
    end if;
    v_org_code := true;
    v_invite.org_id := v_org.id;
    v_invite.target_role := 'student';
    select c.id into v_invite.coach_id
    from public.profiles c
    where c.org_id = v_org.id and c.role = 'coach'
    order by (select count(*) from public.coach_students cs where cs.coach_id = c.id),
             c.created_at, c.id
    limit 1;
    if v_invite.coach_id is null then
      raise exception 'NO_COACH';
    end if;
  end if;

  if v_invite.target_role = 'student' then
    select * into v_org from public.organizations where id = v_invite.org_id;
    if not v_org.is_active then
      raise exception 'ORG_INACTIVE';
    end if;
    if v_org.license_expires_at is not null and v_org.license_expires_at <= now() then
      raise exception 'LICENSE_EXPIRED';
    end if;
    if v_org.credit_balance <= 0 then
      raise exception 'NO_CREDITS';
    end if;

    -- Öğrenci numarası (kayıt moduna göre).
    if v_org.student_registration_mode = 'list' then
      if v_number is null or v_number !~ '^[0-9]{1,20}$' then
        raise exception 'STUDENT_NUMBER_REQUIRED';
      end if;
      select * into v_expected from public.expected_students
      where org_id = v_org.id and student_number = v_number
      for update;
      if not found then
        raise exception 'STUDENT_NUMBER_NOT_FOUND';
      end if;
      if v_expected.status = 'matched'
         or exists (select 1 from public.profiles
                    where org_id = v_org.id and student_number = v_number) then
        raise exception 'STUDENT_NUMBER_TAKEN';
      end if;
      v_name := v_expected.full_name;
      v_store := v_number;
      v_source := 'matched';
    elsif v_number is not null then
      v_source := 'free';
      if exists (select 1 from public.profiles
                 where org_id = v_org.id and student_number = v_number) then
        v_flag := 'duplicate';
        v_attempted := left(v_number, 40);
      elsif v_number ~ '^[0-9]{1,20}$' then
        v_store := v_number;
      elsif v_number ~ '^[0-9A-Z-]{1,20}$' then
        v_store := v_number;
        v_flag := 'bad_format';
      else
        v_flag := 'bad_format';
        v_attempted := left(v_number, 40);
      end if;
    else
      v_source := 'free';
    end if;
  elsif v_invite.target_role = 'teacher' then
    select * into v_org from public.organizations where id = v_invite.org_id;
    if not v_org.is_active then
      raise exception 'ORG_INACTIVE';
    end if;
    if v_org.license_expires_at is not null and v_org.license_expires_at <= now() then
      raise exception 'LICENSE_EXPIRED';
    end if;
    -- 'teacher_branches': ["Matematik", "Geometri"]; yoksa 'Genel'.
    begin
      v_branches := public.clean_teacher_branches(array(
        select jsonb_array_elements_text(p_meta -> 'teacher_branches')));
    exception when others then
      v_branches := '{}';
    end;
    if cardinality(v_branches) = 0 then
      v_branches := array['Genel'];
    end if;
  end if;

  if not p_apply then
    return;
  end if;

  insert into public.profiles
    (id, full_name, role, org_id, kvkk_consent_at, birth_year, grade_level,
     student_number, registration_source, number_flag, attempted_number)
  values (
    p_user_id,
    v_name,
    v_invite.target_role,
    v_invite.org_id,
    case when (p_meta ->> 'kvkk_consent')::boolean then now() end,
    v_birth,
    case when v_invite.target_role = 'student' then v_grade end,
    v_store, v_source, v_flag, v_attempted
  );

  if (p_meta ->> 'kvkk_consent')::boolean then
    insert into public.consents (user_id, kind, granted, version, source, given_by)
    values (p_user_id, 'privacy_notice', true, v_version, 'self', p_user_id);
  end if;

  if v_invite.target_role = 'student' then
    insert into public.coach_students (coach_id, student_id, org_id)
    values (v_invite.coach_id, p_user_id, v_invite.org_id);

    if v_expected.id is not null then
      update public.expected_students
      set status = 'matched', matched_student_id = p_user_id, matched_at = now()
      where id = v_expected.id;
      if v_expected.class_name is not null then
        insert into public.classroom_students (classroom_id, student_id)
        select c.id, p_user_id from public.classrooms c
        where c.org_id = v_org.id and c.active
          and lower(trim(c.name)) = lower(trim(v_expected.class_name))
        order by c.created_at
        limit 1;
      end if;
      if v_expected.guardian_phone is not null then
        insert into public.student_guardian_phones (student_id, tenant_id, phone)
        values (p_user_id, v_org.tenant_id, v_expected.guardian_phone)
        on conflict (student_id) do nothing;
      end if;
    end if;

    if v_invite.guardian_statement_at is not null then
      insert into public.consents (user_id, kind, granted, version, source, given_by)
      values (p_user_id, 'guardian_approval', true, v_version, 'institution',
              v_invite.created_by);
    end if;
    if (p_meta -> 'consents' ->> 'ranking')::boolean then
      insert into public.consents (user_id, kind, granted, version, source, given_by)
      values (p_user_id, 'ranking', true, v_version, 'self', p_user_id);
    end if;

  elsif v_invite.target_role = 'teacher' then
    perform set_config('mentoria.timetable_trusted', 'on', true);
    insert into public.teachers (org_id, full_name, branches, profile_id)
    values (v_invite.org_id, left(v_name, 80), v_branches, p_user_id);
    perform set_config('mentoria.timetable_trusted', 'off', true);

  elsif v_invite.target_role = 'parent' then
    insert into public.parent_students (parent_id, student_id)
    values (p_user_id, v_invite.student_id);

    if (p_meta ->> 'guardian_approval')::boolean then
      insert into public.consents (user_id, kind, granted, version, source, given_by)
      values (v_invite.student_id, 'guardian_approval', true, v_version, 'parent',
              p_user_id);
    end if;
    if (p_meta ->> 'child_ranking')::boolean then
      insert into public.consents (user_id, kind, granted, version, source, given_by)
      values (v_invite.student_id, 'ranking', true, v_version, 'parent', p_user_id);
    end if;
  end if;

  if not v_org_code then
    update public.invite_codes
    set used_count = used_count + 1
    where code = v_code;
  end if;
end;
$$;
revoke all on function public.apply_signup_invite(uuid, jsonb, boolean)
  from public, anon, authenticated;

-- Soru çözümü talepleri: saklama süresi (KVKK)
alter table public.retention_settings
  add column if not exists tutoring_keep interval not null default '1 year'
  check (tutoring_keep >= interval '30 days');

create or replace function public.purge_old_tutoring_requests()
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_keep interval;
  v_n    int;
begin
  select tutoring_keep into v_keep from public.retention_settings;
  with gone as (
    delete from public.tutoring_requests
    where on_date < (now() - v_keep)::date
    returning id
  ), notes as (
    delete from public.notifications n
    using gone
    where n.kind = 'tutoring_request' and n.ref_id = gone.id
  )
  select count(*) into v_n from gone;
  return v_n;
end;
$$;
revoke execute on function public.purge_old_tutoring_requests() from public, anon, authenticated;

create or replace function public.run_retention_jobs()
returns jsonb
language plpgsql security definer set search_path = ''
as $$
begin
  return jsonb_build_object(
    'announcements', public.purge_old_announcements(),
    'expired_org_accounts', public.purge_expired_organizations(),
    'inactive', public.process_inactive_accounts(),
    'tutoring_requests', public.purge_old_tutoring_requests());
end;
$$;
revoke execute on function public.run_retention_jobs() from public, anon, authenticated;
