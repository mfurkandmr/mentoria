-- =====================================================================
-- Hesap kuralları
--  * Öğrenci kendi hesabını silemez; öğrencinin hesabını koçu (ya da kurum
--    müdürü) siler: delete_student_account.
--  * Veli davet kodu 30 gün geçerli (diğer kodlar 14 gün).
--
-- Geri almak için: supabase/rollbacks/20261017170000_account_rules.down.sql
-- =====================================================================

create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- Öğrenci hesabı koç tarafından silinir.
  if v_me.role = 'student' then
    raise exception 'STUDENT_DELETE_BY_COACH';
  end if;

  if v_me.role = 'admin' and not exists (
    select 1 from public.profiles
    where org_id = v_me.org_id and role = 'admin' and id <> v_me.id
  ) then
    raise exception 'LAST_ADMIN';
  end if;

  if v_me.role = 'coach' and exists (
    select 1 from public.coach_students where coach_id = v_me.id
  ) then
    raise exception 'COACH_HAS_STUDENTS';
  end if;

  delete from auth.users where id = v_me.id;
end;
$$;

-- Koç (ya da öğrencinin kurum müdürü) öğrencinin hesabını ve tüm verilerini
-- kalıcı olarak siler. Veriler ON DELETE CASCADE ile gider.
create or replace function public.delete_student_account(p_student uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_target public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  select * into v_target from public.profiles where id = p_student;
  if not found or v_target.role <> 'student' then
    raise exception 'NOT_A_STUDENT';
  end if;
  if not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;

  delete from auth.users where id = p_student;
end;
$$;

revoke execute on function public.delete_student_account(uuid) from public, anon;
grant  execute on function public.delete_student_account(uuid) to authenticated;

-- Davet kodu üretimi: veli kodu 30 gün, diğerleri 14 gün geçerli.
create or replace function public.create_invite(
  p_target_role public.user_role,
  p_coach uuid default null,
  p_max_uses int default 1
)
returns text
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
  else
    raise exception 'NOT_ALLOWED';
  end if;

  loop
    select string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
    into v_code
    from generate_series(1, 8);
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;

  insert into public.invite_codes
    (code, org_id, target_role, coach_id, student_id, created_by, max_uses, expires_at)
  values
    (v_code, v_me.org_id, p_target_role, v_coach, v_student, v_me.id,
     greatest(1, least(p_max_uses, 200)),
     now() + case when p_target_role = 'parent'
                  then interval '30 days' else interval '14 days' end);

  return v_code;
end;
$$;
