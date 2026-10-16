-- Geri alma: 20261017170000_account_rules
-- Öğrenci yeniden kendi hesabını silebilir, koç silme fonksiyonu kalkar,
-- veli kodları yeniden 14 gün geçerli olur (önceki fonksiyonlar birebir).
drop function if exists public.delete_student_account(uuid);

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

  -- Karışan karakterler (0/O, 1/I) olmadan 8 haneli kod
  loop
    select string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
    into v_code
    from generate_series(1, 8);
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;

  insert into public.invite_codes
    (code, org_id, target_role, coach_id, student_id, created_by, max_uses)
  values
    (v_code, v_me.org_id, p_target_role, v_coach, v_student, v_me.id,
     greatest(1, least(p_max_uses, 200)));

  return v_code;
end;
$$;
