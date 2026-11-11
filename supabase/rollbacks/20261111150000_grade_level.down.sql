-- 20261111150000_grade_level geri alma.
drop function if exists public.set_grade_level(uuid, int);

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
    (id, full_name, role, org_id, kvkk_consent_at, birth_year,
     student_number, registration_source, number_flag, attempted_number)
  values (
    p_user_id,
    v_name,
    v_invite.target_role,
    v_invite.org_id,
    case when (p_meta ->> 'kvkk_consent')::boolean then now() end,
    v_birth,
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

alter table public.profiles drop column if exists grade_level;
