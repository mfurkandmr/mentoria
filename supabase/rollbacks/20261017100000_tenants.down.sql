-- Geri alma: 20261017100000_tenants
-- (Önce 20261017110000_tenant_columns.down.sql çalıştırılmalı.)
-- Kurumlar ve kullanıcılar korunur; dershane markaları silinir.

drop function if exists public.create_tenant_admin_invite(uuid);
drop function if exists public.create_tenant(text, text, text, text, text, int);
drop function if exists public.tenant_branding(text);

-- check_invite eski haline döner.
create or replace function public.check_invite(p_code text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object('role', i.target_role, 'org_name', o.name)
  from public.invite_codes i
  join public.organizations o on o.id = i.org_id
  where i.code = upper(trim(p_code))
    and i.expires_at > now()
    and i.used_count < i.max_uses
$$;
revoke execute on function public.check_invite(text) from public;
grant  execute on function public.check_invite(text) to anon, authenticated;

drop policy if exists "members read own tenant"     on public.tenants;
drop policy if exists "super admin inserts tenants" on public.tenants;
drop policy if exists "super admin updates tenants" on public.tenants;
drop policy if exists "super admin deletes tenants" on public.tenants;

drop trigger if exists organizations_default_tenant on public.organizations;
drop function if exists public.organizations_default_tenant();
alter table public.organizations drop column if exists tenant_id;

drop table if exists public.platform_admins;
drop table if exists public.tenants;

drop function if exists public.touch_updated_at();
drop function if exists public.new_invite_code();
drop function if exists public.is_super_admin();
drop function if exists public.unique_tenant_slug(text);
drop function if exists public.slugify(text);
