-- 20261022120000_invite_rate_limit_ip geri alma: 20261022110000'deki check_invite.

create or replace function public.check_invite(p_code text)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_ip text := coalesce(nullif(trim(split_part(
      coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json
        ->> 'x-forwarded-for', ',', 1)), ''), 'unknown');
  v_result jsonb;
begin
  if (select count(*) from public.invite_check_failures
      where ip = v_ip and at > now() - interval '10 minutes') >= 20
     or (select count(*) from public.invite_check_failures
         where at > now() - interval '10 minutes') >= 1000 then
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
