-- 20261022110000_invite_rate_limit geri alma: random() ile kod üretimi ve
-- sınırsız check_invite (20261020100000_org_credits'teki hâlleri).

create or replace function public.check_invite(p_code text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
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
$$;

drop table if exists public.invite_check_failures;

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
    -- Yetişkin öğrenci velisini ancak açık rızasıyla ekler.
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
    select string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
    into v_code
    from generate_series(1, 8);
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

create or replace function public.generate_org_invite_code()
returns text
language plpgsql volatile set search_path = ''
as $$
declare
  v_code text;
begin
  loop
    select 'MENTORIA-' || string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
    into v_code
    from generate_series(1, 6);
    exit when not exists (select 1 from public.organizations where invite_code = v_code)
          and not exists (select 1 from public.invite_codes where code = v_code);
  end loop;
  return v_code;
end;
$$;
revoke execute on function public.generate_org_invite_code() from public, anon, authenticated;

drop function if exists public.random_code(int);
