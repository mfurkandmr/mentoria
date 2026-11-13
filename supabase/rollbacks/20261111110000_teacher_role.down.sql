-- 20261111110000_teacher_role geri alma: create_invite (20261022110000),
-- guard_timetable_row (20261105140000) ve apply_signup_invite (20261105140000)
-- önceki sürümlerine döner; yeni fonksiyonlar silinir. Var olan öğretmen
-- hesapları ve teachers satırları silinmez (enum notu:
-- 20261111100000_teacher_role_enum.down.sql).

drop function if exists public.merge_teachers(uuid, uuid);
drop function if exists public.set_my_teacher_branches(text[]);
drop function if exists public.my_teacher();

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

  if v_me.role = 'admin' and p_target_role = 'coach' then
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
    if not public.is_minor(v_me.id) and not public.has_consent(v_me.id, 'parent_view') then
      raise exception 'PARENT_VIEW_CONSENT_REQUIRED';
    end if;
  else
    raise exception 'NOT_ALLOWED';
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

create or replace function public.guard_timetable_row()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid;
  j jsonb := to_jsonb(new);
  v_allowed boolean;
begin
  if tg_op = 'UPDATE' then
    v_org := old.org_id;
  elsif tg_table_name in ('rooms', 'teachers', 'classrooms', 'time_slots', 'schedules') then
    v_org := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  elsif tg_table_name = 'teacher_availability' then
    v_org := (select org_id from public.teachers where id = (j ->> 'teacher_id')::uuid);
  elsif tg_table_name in ('classroom_students', 'class_lessons') then
    v_org := (select org_id from public.classrooms where id = (j ->> 'classroom_id')::uuid);
  elsif tg_table_name = 'schedule_entries' then
    v_org := (select org_id from public.schedules where id = (j ->> 'schedule_id')::uuid);
  end if;
  v_allowed := auth.uid() is null or public.is_org_admin(v_org)
    or (tg_table_name = 'classroom_students'
        and public.can_manage_student((j ->> 'student_id')::uuid));
  if v_org is null or not v_allowed then
    raise exception 'TIMETABLE_NOT_ADMIN';
  end if;
  new.org_id := v_org;
  new.tenant_id := (select tenant_id from public.organizations where id = v_org);

  if tg_table_name = 'classroom_students' then
    -- Sınıf değişirse yeni sınıf da aynı kurumdan ve aktif olmalı.
    v_org := (select org_id from public.classrooms
              where id = (j ->> 'classroom_id')::uuid and active);
    if v_org is distinct from new.org_id then
      raise exception 'TIMETABLE_BAD_REF';
    end if;
  end if;
  if (j ? 'teacher_id') and j ->> 'teacher_id' is not null
     and not exists (select 1 from public.teachers
                     where id = (j ->> 'teacher_id')::uuid and org_id = new.org_id) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'classroom_id') and j ->> 'classroom_id' is not null
     and not exists (select 1 from public.classrooms
                     where id = (j ->> 'classroom_id')::uuid and org_id = new.org_id) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'room_id') and j ->> 'room_id' is not null
     and not exists (select 1 from public.rooms
                     where id = (j ->> 'room_id')::uuid and org_id = new.org_id) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'home_room_id') and j ->> 'home_room_id' is not null
     and not exists (select 1 from public.rooms
                     where id = (j ->> 'home_room_id')::uuid and org_id = new.org_id) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'time_slot_id') and j ->> 'time_slot_id' is not null
     and not exists (select 1 from public.time_slots
                     where id = (j ->> 'time_slot_id')::uuid and org_id = new.org_id) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if tg_table_name = 'teachers' and j ->> 'profile_id' is not null
     and not exists (select 1 from public.profiles
                     where id = (j ->> 'profile_id')::uuid and org_id = new.org_id
                       and role in ('coach', 'admin')) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if tg_table_name = 'classroom_students'
     and not exists (select 1 from public.profiles
                     where id = (j ->> 'student_id')::uuid and org_id = new.org_id
                       and role = 'student') then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if tg_table_name = 'teachers' then
    new.full_name := trim(j ->> 'full_name');
  end if;
  if tg_table_name = 'schedules' then
    new.updated_at := now();
    if tg_op = 'INSERT' then
      new.created_at := now();
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_timetable_row() from public, anon, authenticated;

-- apply_signup_invite: 20261105140000 sürümü.
-- apply_signup_invite (20261102100000 sürümü) + öğrenci numarası.
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

drop function if exists public.clean_teacher_branches(text[]);
