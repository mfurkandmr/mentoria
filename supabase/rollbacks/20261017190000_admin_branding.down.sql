-- Geri alma: 20261017190000_admin_branding
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    drop policy if exists "admin manages own tenant logos" on storage.objects;
  end if;
end;
$$;
drop function if exists public.update_my_branding(text, text, text, text);
drop trigger if exists sync_tenant_name on public.organizations;
drop function if exists public.sync_tenant_name();
