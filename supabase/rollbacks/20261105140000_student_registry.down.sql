-- Geri alma: 20261105140000_student_registry
-- Kayıt modu, beklenen öğrenci listesi, numara işaretleri, sınıf/numara
-- geçmişi ve yayın bildirimi kalkar; değişen fonksiyonlar önceki
-- sürümlerine döner (check_invite 20261022120000, apply_signup_invite
-- 20261102100000, set_student_number 20261015140000, guard_timetable_row /
-- publish_schedule / save_schedule_entries 20261105130000).

drop function if exists public.schedule_reach(uuid);
drop function if exists public.notify_timetable(uuid, boolean);
drop function if exists public.import_expected_students(jsonb, boolean);
drop function if exists public.set_registration_mode(text);
drop function if exists public.reconcile_expected_students(uuid);
drop function if exists public.my_classroom();
drop function if exists public.managed_students_list();
drop function if exists public.set_student_coach(uuid, uuid);
drop function if exists public.assign_students_to_class(uuid[], uuid);
drop function if exists public.clear_number_flag(uuid);
drop function if exists public.student_number_available(uuid, text);
drop function if exists public.match_student_number(text, text);
drop function if exists public.org_of_student_code(text);

drop trigger if exists log_number_change on public.profiles;
drop function if exists public.log_number_change();
drop trigger if exists log_class_change on public.classroom_students;
drop function if exists public.log_class_change();
drop table if exists public.student_number_history;
drop table if exists public.student_class_history;

drop trigger if exists guard_classroom_delete on public.classrooms;
drop function if exists public.guard_classroom_delete();
drop policy if exists "coach reads org classrooms" on public.classrooms;
drop policy if exists "manager reads class members" on public.classroom_students;
drop policy if exists "student reads own class" on public.classroom_students;
drop index if exists public.classroom_students_one_class;
alter table public.classrooms drop column if exists capacity, drop column if exists active;

drop table if exists public.expected_students;
alter table public.profiles
  drop column if exists registration_source,
  drop column if exists number_flag,
  drop column if exists attempted_number;
revoke select (student_registration_mode) on public.organizations from authenticated;
alter table public.organizations drop column if exists student_registration_mode;

alter table public.schedules drop column if exists published_at;
delete from public.notifications where kind = 'timetable';
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest', 'installment_due'));

-- Önceki sürümler
create or replace function public.check_invite(p_code text)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_headers json := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json;
  -- cf-connecting-ip ve sb-forwarded-for'u Cloudflare/Supabase yazar; istemci
  -- değiştiremez. x-forwarded-for'da istemcinin yazdığı değerler başa eklenir,
  -- bu yüzden yalnızca son değer (sunucunun eklediği) kullanılır.
  v_ip text := coalesce(
    nullif(trim(v_headers ->> 'cf-connecting-ip'), ''),
    nullif(trim(v_headers ->> 'sb-forwarded-for'), ''),
    nullif(trim((regexp_split_to_array(v_headers ->> 'x-forwarded-for', ','))[
      array_length(regexp_split_to_array(v_headers ->> 'x-forwarded-for', ','), 1)]), ''),
    'unknown');
  v_result jsonb;
begin
  if (select count(*) from public.invite_check_failures
      where ip = v_ip and at > now() - interval '10 minutes') >= 30
     or (select count(*) from public.invite_check_failures
         where at > now() - interval '10 minutes') >= 5000 then
    raise exception 'TOO_MANY_ATTEMPTS';
  end if;

  select * into v_result from (
  select jsonb_build_object(
             'role', i.target_role,
             'org_name', o.name,
             -- Veli davetinde: çocuk 18 yaşından küçükse veli onayı istenir.
             'student_minor', case when i.target_role = 'parent'
                                   then public.is_minor(i.student_id) end,
             'no_credits', i.target_role = 'student' and o.credit_balance <= 0,
             'tenant', jsonb_build_object(
               'id', t.id, 'name', t.name, 'slug', t.slug, 'logo_url', t.logo_url,
               'primary_color', t.primary_color,
               'secondary_color', t.secondary_color,
               'font_family', t.font_family,
               'is_active', t.is_active))
    from public.invite_codes i
    join public.organizations o on o.id = i.org_id
    join public.tenants t on t.id = o.tenant_id
    where i.code = upper(trim(p_code))
      and i.expires_at > now()
      and i.used_count < i.max_uses
      and t.is_active
      and o.is_active
    union all
    select jsonb_build_object(
             'role', 'student',
             'org_name', o.name,
             'student_minor', null,
             'no_credits', o.credit_balance <= 0,
             'tenant', jsonb_build_object(
               'id', t.id, 'name', t.name, 'slug', t.slug, 'logo_url', t.logo_url,
               'primary_color', t.primary_color,
               'secondary_color', t.secondary_color,
               'font_family', t.font_family,
               'is_active', t.is_active))
    from public.organizations o
    join public.tenants t on t.id = o.tenant_id
    where o.invite_code = upper(trim(p_code))
      and o.is_active
      and t.is_active
      and (o.license_expires_at is null or o.license_expires_at > now())
    limit 1
  ) r;

  if v_result is null then
    delete from public.invite_check_failures where at < now() - interval '1 hour';
    insert into public.invite_check_failures (ip) values (v_ip);
  end if;
  return v_result;
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
  v_birth     int;
  v_invite    public.invite_codes%rowtype;
  v_org_code  boolean := false;
  v_org       public.organizations%rowtype;
begin
  if v_code is null or v_code = '' then
    raise exception 'INVITE_REQUIRED';
  end if;
  if v_name is null or length(v_name) < 3 then
    raise exception 'NAME_REQUIRED';
  end if;
  -- KVKK: Kullanım Koşulları + Aydınlatma Metni teyidi olmadan hesap açılmaz
  -- (uygulama kutuyu zorunlu tutar; burada doğrudan API çağrısı da reddedilir).
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
    -- Kurum kodu: yalnızca öğrenci kaydı.
    select * into v_org from public.organizations where invite_code = v_code;
    if not found then
      raise exception 'INVITE_INVALID';
    end if;
    v_org_code := true;
    v_invite.org_id := v_org.id;
    v_invite.target_role := 'student';
    -- En az öğrencisi olan koç (eşitlikte en eski koç).
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

  -- Öğrenci: kurum açık, lisans geçerli, kredi var. (Kredi asıl olarak
  -- profil eklenirken consume_student_credit ile düşer.)
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
  end if;

  if not p_apply then
    return;
  end if;

  insert into public.profiles (id, full_name, role, org_id, kvkk_consent_at, birth_year)
  values (
    p_user_id,
    v_name,
    v_invite.target_role,
    v_invite.org_id,
    case when (p_meta ->> 'kvkk_consent')::boolean then now() end,
    v_birth
  );

  if (p_meta ->> 'kvkk_consent')::boolean then
    insert into public.consents (user_id, kind, granted, version, source, given_by)
    values (p_user_id, 'privacy_notice', true, v_version, 'self', p_user_id);
  end if;

  if v_invite.target_role = 'student' then
    insert into public.coach_students (coach_id, student_id, org_id)
    values (v_invite.coach_id, p_user_id, v_invite.org_id);

    -- Kurum, davette veli onayını kendisinin aldığını beyan ettiyse.
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

create or replace function public.set_student_number(p_student uuid, p_number text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_number text := nullif(upper(trim(p_number)), '');
begin
  if not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_number is not null and v_number !~ '^[0-9A-Z-]{1,20}$' then
    raise exception 'INVALID_NUMBER';
  end if;
  update public.profiles
  set student_number = v_number
  where id = p_student and role = 'student';
exception
  when unique_violation then
    raise exception 'NUMBER_TAKEN';
end;
$$;

create or replace function public.guard_timetable_row()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid;
  j jsonb := to_jsonb(new);
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
  -- Doğrudan istekte çağıran o kurumun müdürü olmalı (RLS de denetler;
  -- burada başka kurumun üst kaydına iliştirmeyi de keser).
  if v_org is null or (auth.uid() is not null and not public.is_org_admin(v_org)) then
    raise exception 'TIMETABLE_NOT_ADMIN';
  end if;
  new.org_id := v_org;
  new.tenant_id := (select tenant_id from public.organizations where id = v_org);

  if (j ? 'teacher_id') and j ->> 'teacher_id' is not null
     and not exists (select 1 from public.teachers
                     where id = (j ->> 'teacher_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'classroom_id') and j ->> 'classroom_id' is not null
     and not exists (select 1 from public.classrooms
                     where id = (j ->> 'classroom_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'room_id') and j ->> 'room_id' is not null
     and not exists (select 1 from public.rooms
                     where id = (j ->> 'room_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'home_room_id') and j ->> 'home_room_id' is not null
     and not exists (select 1 from public.rooms
                     where id = (j ->> 'home_room_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'time_slot_id') and j ->> 'time_slot_id' is not null
     and not exists (select 1 from public.time_slots
                     where id = (j ->> 'time_slot_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if tg_table_name = 'teachers' and j ->> 'profile_id' is not null
     and not exists (select 1 from public.profiles
                     where id = (j ->> 'profile_id')::uuid and org_id = v_org
                       and role in ('coach', 'admin')) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if tg_table_name = 'classroom_students'
     and not exists (select 1 from public.profiles
                     where id = (j ->> 'student_id')::uuid and org_id = v_org
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

create or replace function public.publish_schedule(p_schedule uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.schedules where id = p_schedule);
begin
  if v_org is null or not public.is_org_admin(v_org) then
    raise exception 'TIMETABLE_NOT_ADMIN';
  end if;
  update public.schedules set status = 'draft'
  where org_id = v_org and status = 'published' and id <> p_schedule;
  update public.schedules set status = 'published' where id = p_schedule;
end;
$$;

create or replace function public.save_schedule_entries(
  p_schedule uuid, p_entries jsonb, p_soft_score integer default null)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.schedules where id = p_schedule);
  v_n int;
begin
  if v_org is null or not public.is_org_admin(v_org) then
    raise exception 'TIMETABLE_NOT_ADMIN';
  end if;
  if jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) > 5000 then
    raise exception 'TIMETABLE_BAD_INPUT';
  end if;
  delete from public.schedule_entries where schedule_id = p_schedule;
  insert into public.schedule_entries
    (schedule_id, teacher_id, classroom_id, room_id, time_slot_id, branch, locked)
  select p_schedule, (e ->> 'teacher_id')::uuid, (e ->> 'classroom_id')::uuid,
         nullif(e ->> 'room_id', '')::uuid, (e ->> 'time_slot_id')::uuid,
         e ->> 'branch', coalesce((e ->> 'locked')::boolean, false)
  from jsonb_array_elements(p_entries) e;
  get diagnostics v_n = row_count;
  update public.schedules set soft_score = p_soft_score where id = p_schedule;
  return v_n;
end;
$$;
