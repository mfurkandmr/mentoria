-- Geri alma: 20261017130000_tenant_logo_storage
-- Supabase, storage.objects tablosundan doğrudan silmeye izin vermez;
-- kova doluysa önce Dashboard > Storage > tenant-logos içindeki dosyaları silin.
do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'storage') then
    return;
  end if;
  drop policy if exists "super admin reads tenant logos"   on storage.objects;
  drop policy if exists "super admin uploads tenant logos" on storage.objects;
  drop policy if exists "super admin updates tenant logos" on storage.objects;
  drop policy if exists "super admin deletes tenant logos" on storage.objects;
  if not exists (select 1 from storage.objects where bucket_id = 'tenant-logos') then
    delete from storage.buckets where id = 'tenant-logos';
  else
    raise notice 'tenant-logos kovası boş değil; dosyaları silip kovayı elle kaldırın';
  end if;
end;
$$;
