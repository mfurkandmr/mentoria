-- Geri alma: 20261018110000_tenant_fonts
-- Fonksiyonlar yazı tipinden önceki hallerine döner, kolon kalkar.

drop function if exists public.update_my_branding(text, text, text, text, text);
create function public.update_my_branding(
  p_name            text,
  p_primary_color   text,
  p_secondary_color text,
  p_logo_url        text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_tenant uuid := public.my_tenant();
  v_logo   text := nullif(trim(p_logo_url), '');
begin
  if v_tenant is null or public.my_role() <> 'admin' then
    raise exception 'NOT_ALLOWED';
  end if;
  if length(trim(coalesce(p_name, ''))) < 2 then
    raise exception 'NAME_REQUIRED';
  end if;
  if v_logo is not null
     and v_logo not like '%/storage/v1/object/public/tenant-logos/' || v_tenant::text || '/%' then
    raise exception 'LOGO_NOT_ALLOWED';
  end if;

  update public.tenants
  set name = left(trim(p_name), 80),
      primary_color = upper(p_primary_color),
      secondary_color = upper(p_secondary_color),
      logo_url = v_logo
  where id = v_tenant;

  if (select count(*) from public.organizations where tenant_id = v_tenant) = 1 then
    update public.organizations
    set name = left(trim(p_name), 80)
    where tenant_id = v_tenant and name is distinct from left(trim(p_name), 80);
  end if;
end;
$$;
revoke execute on function public.update_my_branding(text, text, text, text) from public, anon;
grant  execute on function public.update_my_branding(text, text, text, text) to authenticated;

create or replace function public.tenant_branding(p_slug text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
           'id', t.id, 'name', t.name, 'slug', t.slug, 'logo_url', t.logo_url,
           'primary_color', t.primary_color, 'secondary_color', t.secondary_color,
           'is_active', t.is_active)
  from public.tenants t
  where t.slug = lower(trim(p_slug)) and t.is_active
$$;

create or replace function public.check_invite(p_code text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
           'role', i.target_role,
           'org_name', o.name,
           'tenant', jsonb_build_object(
             'id', t.id, 'name', t.name, 'slug', t.slug, 'logo_url', t.logo_url,
             'primary_color', t.primary_color,
             'secondary_color', t.secondary_color,
             'is_active', t.is_active))
  from public.invite_codes i
  join public.organizations o on o.id = i.org_id
  join public.tenants t on t.id = o.tenant_id
  where i.code = upper(trim(p_code))
    and i.expires_at > now()
    and i.used_count < i.max_uses
    and t.is_active
$$;

alter table public.tenants drop column if exists font_family;
