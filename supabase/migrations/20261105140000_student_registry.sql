-- =====================================================================
-- Sınıf yönetimi, öğrenci kayıt modları ve sınıfa özel ders programı
-- ---------------------------------------------------------------------
--  * organizations.student_registration_mode: 'free' (varsayılan; mevcut
--    kurumlar) | 'list'. Liste modunda öğrenci kayıtta girdiği numara
--    expected_students'ta yoksa kayıt reddedilir; varsa ad soyad (ve sınıf,
--    veli telefonu) listeden gelir. Serbest modda kayıt engellenmez,
--    sorunlu numaralar profiles.number_flag ile işaretlenir.
--  * expected_students: kurumun beklenen öğrenci listesi (hesap açmaz).
--    Yalnızca müdür okur/yazar; kayıt ekranındaki anlık kontrol
--    match_student_number ile (yalnızca durum döner, hız sınırlı).
--  * profiles: registration_source, number_flag, attempted_number.
--  * classroom_students: öğrenci başına tek sınıf. Koç kendi öğrencisini
--    atar (assign_students_to_class), müdür herkesi. İçinde öğrenci olan
--    sınıf silinemez. classrooms: capacity, active.
--  * student_class_history / student_number_history: tetikleyiciyle.
--  * set_student_number: yalnızca rakam (1-20). set_student_coach (müdür),
--    clear_number_flag, student_number_available, managed_students_list,
--    my_classroom, set_registration_mode, import_expected_students.
--  * Yayın: schedules.published_at; yayınlanınca (ve yayındaki program
--    kaydedilince, kişi başı 30 dakikada bir) öğrencilere ve bağlı
--    öğretmenlere 'timetable' bildirimi.
--
-- Geri almak için: supabase/rollbacks/20261105140000_student_registry.down.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- Kurum ayarı ve öğrenci alanları
-- ---------------------------------------------------------------------
alter table public.organizations
  add column student_registration_mode text not null default 'free'
    check (student_registration_mode in ('free', 'list'));
grant select (student_registration_mode) on public.organizations to authenticated;

alter table public.profiles
  add column registration_source text
    check (registration_source in ('matched', 'free')),
  add column number_flag text
    check (number_flag in ('bad_format', 'duplicate', 'not_in_list')),
  add column attempted_number text check (length(attempted_number) <= 40);

create table public.expected_students (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations (id) on delete cascade,
  tenant_id          uuid not null references public.tenants (id),
  student_number     text not null check (student_number ~ '^[0-9]{1,20}$'),
  full_name          text not null check (length(trim(full_name)) between 2 and 80),
  class_name         text check (length(class_name) <= 60),
  guardian_phone     text check (guardian_phone ~ '^\+905[0-9]{9}$'),
  status             text not null default 'pending' check (status in ('pending', 'matched')),
  matched_student_id uuid references public.profiles (id) on delete set null,
  matched_at         timestamptz,
  uploaded_by        uuid references public.profiles (id) on delete set null,
  uploaded_at        timestamptz not null default now(),
  unique (org_id, student_number)
);
create index on public.expected_students (tenant_id);
create index on public.expected_students (matched_student_id);
create index on public.expected_students (uploaded_by);

alter table public.expected_students enable row level security;
create policy "org admin manages expected" on public.expected_students
  for all to authenticated
  using ((select public.is_org_admin(org_id)))
  with check ((select public.is_org_admin(org_id)));
create policy "tenant isolation" on public.expected_students as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()));
revoke all on public.expected_students from anon;
-- Yazma yalnızca import_expected_students ile (eşleşme durumu korunur).
revoke insert, update, truncate, trigger, references on public.expected_students from authenticated;

-- ---------------------------------------------------------------------
-- Sınıflar: kapasite, aktiflik, öğrenci başına tek sınıf
-- ---------------------------------------------------------------------
alter table public.classrooms
  add column capacity smallint check (capacity between 1 and 1000),
  add column active boolean not null default true;

-- Önceki sürümde bir öğrenci birden çok sınıfta olabiliyordu: en eskisi kalır.
delete from public.classroom_students a
using public.classroom_students b
where a.student_id = b.student_id and a.ctid > b.ctid;
create unique index classroom_students_one_class
  on public.classroom_students (student_id);

-- Koç kendi kurumunun sınıflarını ve kendi öğrencilerinin sınıfını okur.
create policy "coach reads org classrooms" on public.classrooms
  for select to authenticated
  using (org_id = (select public.my_org()) and (select public.my_role()) = 'coach');
create policy "manager reads class members" on public.classroom_students
  for select to authenticated
  using ((select public.can_manage_student(student_id)));
create policy "student reads own class" on public.classroom_students
  for select to authenticated
  using (student_id = (select auth.uid()));

-- İçinde öğrenci olan sınıf silinemez (kurum silinirken geçer).
create or replace function public.guard_classroom_delete()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if exists (select 1 from public.classroom_students where classroom_id = old.id)
     and exists (select 1 from public.organizations where id = old.org_id) then
    raise exception 'CLASSROOM_NOT_EMPTY';
  end if;
  return old;
end;
$$;
revoke all on function public.guard_classroom_delete() from public, anon, authenticated;
create trigger guard_classroom_delete before delete on public.classrooms
  for each row execute function public.guard_classroom_delete();

-- guard_timetable_row: sınıf üyeliğini koç da (kendi öğrencisi için) yazar.
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

-- ---------------------------------------------------------------------
-- Değişiklik geçmişi
-- ---------------------------------------------------------------------
create table public.student_class_history (
  id             uuid primary key default gen_random_uuid(),
  student_id     uuid not null references public.profiles (id) on delete cascade,
  tenant_id      uuid references public.tenants (id),
  old_classroom  uuid references public.classrooms (id) on delete set null,
  new_classroom  uuid references public.classrooms (id) on delete set null,
  old_name       text,
  new_name       text,
  changed_by     uuid references public.profiles (id) on delete set null,
  changed_role   text,
  changed_at     timestamptz not null default now()
);
create index on public.student_class_history (student_id, changed_at desc);
create index on public.student_class_history (tenant_id);
create index on public.student_class_history (old_classroom);
create index on public.student_class_history (new_classroom);
create index on public.student_class_history (changed_by);

create table public.student_number_history (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.profiles (id) on delete cascade,
  tenant_id    uuid references public.tenants (id),
  old_number   text,
  new_number   text,
  changed_by   uuid references public.profiles (id) on delete set null,
  changed_role text,
  changed_at   timestamptz not null default now()
);
create index on public.student_number_history (student_id, changed_at desc);
create index on public.student_number_history (tenant_id);
create index on public.student_number_history (changed_by);

do $$
declare
  t text;
begin
  foreach t in array array['student_class_history', 'student_number_history'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "manager reads history" on public.%I for select to authenticated
                    using ((select public.can_manage_student(student_id)))', t);
    execute format('create policy "tenant isolation" on public.%I as restrictive for all to public
                    using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
                    with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke insert, update, delete, truncate, trigger, references on public.%I from authenticated', t);
  end loop;
end;
$$;

create or replace function public.log_class_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_student uuid := coalesce(new.student_id, old.student_id);
  v_old uuid := case when tg_op = 'INSERT' then null else old.classroom_id end;
  v_new uuid := case when tg_op = 'DELETE' then null else new.classroom_id end;
begin
  if v_old is not distinct from v_new then
    return null;
  end if;
  -- Öğrenci hesabı silinirken geçmiş yazılmaz (zaten silinecek).
  if not exists (select 1 from public.profiles where id = v_student) then
    return null;
  end if;
  insert into public.student_class_history
    (student_id, tenant_id, old_classroom, new_classroom, old_name, new_name,
     changed_by, changed_role)
  values (
    v_student,
    coalesce(new.tenant_id, old.tenant_id),
    v_old, v_new,
    (select name from public.classrooms where id = v_old),
    (select name from public.classrooms where id = v_new),
    auth.uid(),
    coalesce((select role::text from public.profiles where id = auth.uid()), 'system'));
  return null;
end;
$$;
revoke all on function public.log_class_change() from public, anon, authenticated;
create trigger log_class_change after insert or update or delete on public.classroom_students
  for each row execute function public.log_class_change();

create or replace function public.log_number_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.student_number is distinct from new.student_number then
    insert into public.student_number_history
      (student_id, tenant_id, old_number, new_number, changed_by, changed_role)
    values (new.id, new.tenant_id, old.student_number, new.student_number,
            auth.uid(),
            coalesce((select role::text from public.profiles where id = auth.uid()), 'system'));
  end if;
  return null;
end;
$$;
revoke all on function public.log_number_change() from public, anon, authenticated;
create trigger log_number_change after update of student_number on public.profiles
  for each row execute function public.log_number_change();

-- ---------------------------------------------------------------------
-- Kayıt: öğrenci numarası
-- ---------------------------------------------------------------------
-- Davet ya da kurum kodundan kurum (yalnızca öğrenci kaydı için).
create or replace function public.org_of_student_code(p_code text)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select i.org_id from public.invite_codes i
     where i.code = upper(trim(p_code)) and i.target_role = 'student'
       and i.expires_at > now() and i.used_count < i.max_uses),
    (select o.id from public.organizations o where o.invite_code = upper(trim(p_code))))
$$;
revoke all on function public.org_of_student_code(text) from public, anon, authenticated;

-- Kayıt ekranındaki anlık kontrol: 'ok' | 'not_found' | 'taken' | 'invalid'.
-- Liste dışarı sızmasın diye ad döndürmez; bulunamayan denemeler davet
-- kodu ile aynı hız sınırına (invite_check_failures) sayılır.
create or replace function public.match_student_number(p_code text, p_number text)
returns text
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_headers json := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json;
  v_ip text := coalesce(
    nullif(trim(v_headers ->> 'cf-connecting-ip'), ''),
    nullif(trim(v_headers ->> 'sb-forwarded-for'), ''),
    nullif(trim((regexp_split_to_array(v_headers ->> 'x-forwarded-for', ','))[
      array_length(regexp_split_to_array(v_headers ->> 'x-forwarded-for', ','), 1)]), ''),
    'unknown');
  v_org uuid;
  v_mode text;
  v_number text := regexp_replace(coalesce(p_number, ''), '\s', '', 'g');
  v_row public.expected_students%rowtype;
begin
  if (select count(*) from public.invite_check_failures
      where ip = v_ip and at > now() - interval '10 minutes') >= 30
     or (select count(*) from public.invite_check_failures
         where at > now() - interval '10 minutes') >= 5000 then
    raise exception 'TOO_MANY_ATTEMPTS';
  end if;
  if v_number !~ '^[0-9]{1,20}$' then
    return 'invalid';
  end if;
  v_org := public.org_of_student_code(p_code);
  if v_org is null then
    insert into public.invite_check_failures (ip) values (v_ip);
    return 'not_found';
  end if;
  select student_registration_mode into v_mode from public.organizations where id = v_org;
  if exists (select 1 from public.profiles
             where org_id = v_org and student_number = v_number) then
    return 'taken';
  end if;
  if v_mode = 'free' then
    return 'ok';
  end if;
  select * into v_row from public.expected_students
  where org_id = v_org and student_number = v_number;
  if not found then
    insert into public.invite_check_failures (ip) values (v_ip);
    return 'not_found';
  end if;
  return case when v_row.status = 'matched' then 'taken' else 'ok' end;
end;
$$;
revoke all on function public.match_student_number(text, text) from public;
grant execute on function public.match_student_number(text, text) to anon, authenticated;

-- check_invite: öğrenci davetinde kayıt modu da döner ('number_mode').
create or replace function public.check_invite(p_code text)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_headers json := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json;
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
             'student_minor', case when i.target_role = 'parent'
                                   then public.is_minor(i.student_id) end,
             'no_credits', i.target_role = 'student' and o.credit_balance <= 0,
             'number_mode', case when i.target_role = 'student'
                                 then o.student_registration_mode end,
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
             'number_mode', o.student_registration_mode,
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

-- ---------------------------------------------------------------------
-- Müdür / koç işlemleri
-- ---------------------------------------------------------------------
-- Numara yalnızca rakam (1-20). Geçerli numara girilince işaret kalkar.
create or replace function public.set_student_number(p_student uuid, p_number text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_number text := nullif(regexp_replace(coalesce(p_number, ''), '\s', '', 'g'), '');
begin
  if not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_number is not null and v_number !~ '^[0-9]{1,20}$' then
    raise exception 'INVALID_NUMBER';
  end if;
  update public.profiles
  set student_number = v_number,
      number_flag = case when v_number is null then number_flag
                         when number_flag = 'not_in_list' and exists (
                           select 1 from public.expected_students e
                           where e.org_id = profiles.org_id and e.student_number = v_number)
                           then null
                         when number_flag = 'not_in_list' then number_flag
                         else null end,
      attempted_number = case when v_number is null then attempted_number end
  where id = p_student and role = 'student';
exception
  when unique_violation then
    raise exception 'NUMBER_TAKEN';
end;
$$;

-- Numara boşta mı (kendisi hariç)?
create or replace function public.student_number_available(p_student uuid, p_number text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select public.can_manage_student(p_student) and not exists (
    select 1 from public.profiles me
    join public.profiles o on o.org_id = me.org_id and o.id <> me.id
    where me.id = p_student
      and o.student_number = regexp_replace(coalesce(p_number, ''), '\s', '', 'g'))
$$;
revoke all on function public.student_number_available(uuid, text) from public, anon;
grant execute on function public.student_number_available(uuid, text) to authenticated;

create or replace function public.clear_number_flag(p_student uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  update public.profiles set number_flag = null, attempted_number = null
  where id = p_student and role = 'student';
end;
$$;
revoke all on function public.clear_number_flag(uuid) from public, anon;
grant execute on function public.clear_number_flag(uuid) to authenticated;

-- Öğrencileri sınıfa ata (p_classroom null: sınıftan çıkar).
create or replace function public.assign_students_to_class(p_students uuid[], p_classroom uuid)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  s uuid;
  v_n int := 0;
begin
  if coalesce(cardinality(p_students), 0) > 2000 then
    raise exception 'TOO_MANY';
  end if;
  if p_classroom is not null and not exists (
    select 1 from public.classrooms c
    where c.id = p_classroom and c.active and c.org_id = public.my_org()) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  foreach s in array coalesce(p_students, '{}') loop
    if not public.can_manage_student(s) then
      raise exception 'NOT_ALLOWED';
    end if;
    if p_classroom is null then
      delete from public.classroom_students where student_id = s;
    else
      insert into public.classroom_students (classroom_id, student_id)
      values (p_classroom, s)
      on conflict (student_id) do update set classroom_id = excluded.classroom_id
        where public.classroom_students.classroom_id <> excluded.classroom_id;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;
revoke all on function public.assign_students_to_class(uuid[], uuid) from public, anon;
grant execute on function public.assign_students_to_class(uuid[], uuid) to authenticated;

-- Öğrencinin koçu (yalnızca müdür).
create or replace function public.set_student_coach(p_student uuid, p_coach uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.profiles where id = p_student and role = 'student');
begin
  if v_org is null or not public.is_org_admin(v_org) then
    raise exception 'NOT_ALLOWED';
  end if;
  if not exists (select 1 from public.profiles
                 where id = p_coach and org_id = v_org and role = 'coach') then
    raise exception 'BAD_COACH';
  end if;
  delete from public.coach_students where student_id = p_student;
  insert into public.coach_students (coach_id, student_id, org_id)
  values (p_coach, p_student, v_org);
end;
$$;
revoke all on function public.set_student_coach(uuid, uuid) from public, anon;
grant execute on function public.set_student_coach(uuid, uuid) to authenticated;

-- Yönettiğim öğrenciler: numara, sınıf, koç, işaret.
create or replace function public.managed_students_list()
returns table (
  student_id          uuid,
  full_name           text,
  student_number      text,
  classroom_id        uuid,
  classroom_name      text,
  coach_id            uuid,
  coach_name          text,
  number_flag         text,
  attempted_number    text,
  registration_source text,
  created_at          timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.full_name, p.student_number, cs.classroom_id, c.name,
         co.id, co.full_name, p.number_flag, p.attempted_number,
         p.registration_source, p.created_at
  from public.my_managed_students() m(id)
  join public.profiles p on p.id = m.id and p.role = 'student'
  left join public.classroom_students cs on cs.student_id = p.id
  left join public.classrooms c on c.id = cs.classroom_id
  left join lateral (
    select x.id, x.full_name from public.coach_students k
    join public.profiles x on x.id = k.coach_id
    where k.student_id = p.id
    order by k.created_at
    limit 1) co on true
  order by p.full_name
$$;
revoke all on function public.managed_students_list() from public, anon;
grant execute on function public.managed_students_list() to authenticated;

-- Öğrencinin sınıfı (yoksa satır yok).
create or replace function public.my_classroom()
returns table (classroom_id uuid, classroom_name text)
language sql stable security definer set search_path = ''
as $$
  select c.id, c.name from public.classroom_students cs
  join public.classrooms c on c.id = cs.classroom_id
  where cs.student_id = auth.uid()
$$;
revoke all on function public.my_classroom() from public, anon;
grant execute on function public.my_classroom() to authenticated;

-- Liste ile eşleştir: listede olup numarası tutan öğrenciler "eşleşti",
-- liste modundaysa numarası listede olmayanlar 'not_in_list'.
create or replace function public.reconcile_expected_students(p_org uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.expected_students e
  set status = 'matched', matched_student_id = p.id, matched_at = now()
  from public.profiles p
  where e.org_id = p_org and e.status = 'pending'
    and p.org_id = p_org and p.role = 'student'
    and p.student_number = e.student_number;
  update public.expected_students e
  set status = 'pending', matched_student_id = null, matched_at = null
  where e.org_id = p_org and e.status = 'matched'
    and not exists (select 1 from public.profiles p
                    where p.id = e.matched_student_id and p.org_id = p_org
                      and p.student_number = e.student_number);
  if (select student_registration_mode from public.organizations where id = p_org) = 'list' then
    update public.profiles p
    set number_flag = 'not_in_list'
    where p.org_id = p_org and p.role = 'student' and p.number_flag is null
      and not exists (select 1 from public.expected_students e
                      where e.org_id = p_org and e.student_number = p.student_number);
    update public.profiles p
    set number_flag = null
    where p.org_id = p_org and p.role = 'student' and p.number_flag = 'not_in_list'
      and exists (select 1 from public.expected_students e
                  where e.org_id = p_org and e.student_number = p.student_number);
  else
    update public.profiles p set number_flag = null
    where p.org_id = p_org and p.role = 'student' and p.number_flag = 'not_in_list';
  end if;
end;
$$;
revoke all on function public.reconcile_expected_students(uuid) from public, anon, authenticated;

create or replace function public.set_registration_mode(p_mode text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
begin
  if v_org is null then
    raise exception 'NOT_ALLOWED';
  end if;
  if p_mode not in ('free', 'list') then
    raise exception 'BAD_MODE';
  end if;
  update public.organizations set student_registration_mode = p_mode where id = v_org;
  perform public.reconcile_expected_students(v_org);
end;
$$;
revoke all on function public.set_registration_mode(text) from public, anon;
grant execute on function public.set_registration_mode(text) to authenticated;

-- Liste yükle: p_rows [{number, name, class, phone}]. Aynı numara
-- güncellenir (eşleşme durumu korunur). p_replace: listede olmayan ve
-- eşleşmemiş satırlar silinir. Döner: {inserted, updated, removed}.
create or replace function public.import_expected_students(p_rows jsonb, p_replace boolean default false)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  v_tenant uuid;
  v_ins int := 0;
  v_upd int := 0;
  v_del int := 0;
  r jsonb;
  v_number text;
begin
  if v_org is null then
    raise exception 'NOT_ALLOWED';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 10000 then
    raise exception 'BAD_INPUT';
  end if;
  v_tenant := (select tenant_id from public.organizations where id = v_org);
  for r in select * from jsonb_array_elements(p_rows) loop
    v_number := regexp_replace(coalesce(r ->> 'number', ''), '\s', '', 'g');
    if v_number !~ '^[0-9]{1,20}$' or length(trim(coalesce(r ->> 'name', ''))) < 2 then
      raise exception 'BAD_ROW %', v_number;
    end if;
    insert into public.expected_students
      (org_id, tenant_id, student_number, full_name, class_name, guardian_phone, uploaded_by)
    values (
      v_org, v_tenant, v_number, left(trim(r ->> 'name'), 80),
      left(nullif(trim(r ->> 'class'), ''), 60),
      case when r ->> 'phone' ~ '^\+905[0-9]{9}$' then r ->> 'phone' end,
      auth.uid())
    on conflict (org_id, student_number) do update
      set full_name = excluded.full_name, class_name = excluded.class_name,
          guardian_phone = excluded.guardian_phone,
          uploaded_by = excluded.uploaded_by, uploaded_at = now();
    if (select xmax from public.expected_students
        where org_id = v_org and student_number = v_number) = 0 then
      v_ins := v_ins + 1;
    else
      v_upd := v_upd + 1;
    end if;
  end loop;
  if p_replace then
    with gone as (
      delete from public.expected_students e
      where e.org_id = v_org and e.status = 'pending'
        and not exists (select 1 from jsonb_array_elements(p_rows) x
                        where regexp_replace(coalesce(x ->> 'number', ''), '\s', '', 'g')
                              = e.student_number)
      returning 1)
    select count(*) into v_del from gone;
  end if;
  perform public.reconcile_expected_students(v_org);
  return jsonb_build_object('inserted', v_ins, 'updated', v_upd, 'removed', v_del);
end;
$$;
revoke all on function public.import_expected_students(jsonb, boolean) from public, anon;
grant execute on function public.import_expected_students(jsonb, boolean) to authenticated;

-- ---------------------------------------------------------------------
-- Yayın tarihi ve bildirim
-- ---------------------------------------------------------------------
alter table public.schedules add column published_at timestamptz;

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest', 'installment_due',
                  'timetable'));

-- Programdaki sınıfların öğrencilerine ve bağlı öğretmenlere bildirim.
-- p_updated: yayındaki program değişti (kişi başı 30 dakikada bir).
create or replace function public.notify_timetable(p_schedule uuid, p_updated boolean)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_name text := (select name from public.schedules where id = p_schedule);
  v_n int;
begin
  with targets as (
    select cs.student_id uid
    from public.schedule_entries e
    join public.classroom_students cs on cs.classroom_id = e.classroom_id
    where e.schedule_id = p_schedule
    union
    select t.profile_id
    from public.schedule_entries e
    join public.teachers t on t.id = e.teacher_id
    where e.schedule_id = p_schedule and t.profile_id is not null
  ), sent as (
    insert into public.notifications (user_id, kind, data, ref_id)
    select x.uid, 'timetable',
           jsonb_build_object(
             'name', v_name,
             'updated', p_updated,
             'route', case p.role when 'student' then '/student/timetable'
                                  when 'admin' then '/admin'
                                  else '/coach' end),
           p_schedule
    from targets x
    join public.profiles p on p.id = x.uid
      and (not p_updated or not exists (
        select 1 from public.notifications n
        where n.user_id = x.uid and n.kind = 'timetable'
          and n.created_at > now() - interval '30 minutes'))
    returning 1
  )
  select count(*) into v_n from sent;
  return v_n;
end;
$$;
revoke all on function public.notify_timetable(uuid, boolean) from public, anon, authenticated;

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
  update public.schedules set status = 'published', published_at = now()
  where id = p_schedule;
  perform public.notify_timetable(p_schedule, false);
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
  if (select status from public.schedules where id = p_schedule) = 'published' then
    perform public.notify_timetable(p_schedule, true);
  end if;
  return v_n;
end;
$$;

-- Yayınlanırsa etkilenecek sınıf ve öğrenci sayısı.
create or replace function public.schedule_reach(p_schedule uuid)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select case when public.is_org_admin(s.org_id) then jsonb_build_object(
    'classes', (select count(distinct e.classroom_id) from public.schedule_entries e
                where e.schedule_id = s.id),
    'students', (select count(distinct cs.student_id) from public.schedule_entries e
                 join public.classroom_students cs on cs.classroom_id = e.classroom_id
                 where e.schedule_id = s.id)) end
  from public.schedules s where s.id = p_schedule
$$;
revoke all on function public.schedule_reach(uuid) from public, anon;
grant execute on function public.schedule_reach(uuid) to authenticated;
