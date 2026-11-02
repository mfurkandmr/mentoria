-- Geri alma: 20261031110000_license_access
-- my_tenant_active 20261017110000_tenant_columns sürümüne döner (lisans
-- yalnızca yeni kaydı engeller).
drop trigger if exists guard_invite_license on public.invite_codes;
drop function if exists public.guard_invite_license();

create or replace function public.my_tenant_active()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce((select t.is_active from public.tenants t
                   where t.id = public.my_tenant()), false)
$$;

drop function if exists public.my_license_active();
