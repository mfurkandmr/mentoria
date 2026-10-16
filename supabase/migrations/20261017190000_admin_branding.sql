-- =====================================================================
-- Kurum müdürü kendi markasını yönetir
--
--  * update_my_branding: müdür kendi dershanesinin adını, renklerini ve
--    logosunu değiştirir. Slug ve aktiflik yalnızca süper adminde kalır.
--  * Kurum adı ↔ dershane adı eşitlenir (dershanenin tek kurumu varsa):
--    müdür kurum kartından adı değiştirince koç ve öğrenciler de yeni adı görür.
--  * Logo: müdür yalnızca kendi dershanesinin klasörüne
--    (tenant-logos/<tenant_id>/...) yükleyebilir.
--
-- Geri almak için: supabase/rollbacks/20261017190000_admin_branding.down.sql
-- =====================================================================

-- Tek kurumlu dershanede kurum adı değişince marka adı da değişir.
create or replace function public.sync_tenant_name()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.name is distinct from old.name
     and (select count(*) from public.organizations where tenant_id = new.tenant_id) = 1 then
    update public.tenants
    set name = left(trim(new.name), 80)
    where id = new.tenant_id and name is distinct from left(trim(new.name), 80);
  end if;
  return new;
end;
$$;
revoke execute on function public.sync_tenant_name() from public, anon, authenticated;

create trigger sync_tenant_name
  after update of name on public.organizations
  for each row execute function public.sync_tenant_name();

create or replace function public.update_my_branding(
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
  -- Logo yalnızca bu dershanenin Storage klasöründen olabilir.
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

  -- Tek kurumlu dershanede kurum adı da aynı olsun.
  if (select count(*) from public.organizations where tenant_id = v_tenant) = 1 then
    update public.organizations
    set name = left(trim(p_name), 80)
    where tenant_id = v_tenant and name is distinct from left(trim(p_name), 80);
  end if;
end;
$$;
revoke execute on function public.update_my_branding(text, text, text, text) from public, anon;
grant  execute on function public.update_my_branding(text, text, text, text) to authenticated;

-- Müdür kendi dershanesinin logo klasörüne yazabilir.
do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'storage') then
    return;
  end if;
  execute $p$
    create policy "admin manages own tenant logos" on storage.objects
      for all to authenticated
      using (bucket_id = 'tenant-logos'
             and (select public.my_role()) = 'admin'
             and (storage.foldername(name))[1] = (select public.my_tenant())::text)
      with check (bucket_id = 'tenant-logos'
                  and (select public.my_role()) = 'admin'
                  and (storage.foldername(name))[1] = (select public.my_tenant())::text)
  $p$;
end;
$$;
