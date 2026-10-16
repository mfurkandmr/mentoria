-- =====================================================================
-- White label 4/4: Dershane logoları için Storage kovası
--
--  * "tenant-logos" herkese açık okunur (giriş ekranında, oturum açmadan
--    da logo görünsün). PNG/JPEG/WebP, en fazla 1 MB.
--  * Yükleme/değiştirme/silme yalnızca süper admin.
--  Yerel test ortamında (storage şeması yoksa) hiçbir şey yapmaz.
--
-- Geri almak için: supabase/rollbacks/20261017130000_tenant_logo_storage.down.sql
-- =====================================================================

do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'storage') then
    raise notice 'storage şeması yok, logo kovası atlandı';
    return;
  end if;

  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('tenant-logos', 'tenant-logos', true, 1048576,
          array['image/png', 'image/jpeg', 'image/webp'])
  on conflict (id) do update
    set public = excluded.public,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

  -- Herkese açık kova /public/ adresinden RLS'siz okunur; API ile listeleme
  -- ve üzerine yazma (upsert) için süper admin okuma izni gerekir.
  execute $p$
    create policy "super admin reads tenant logos" on storage.objects
      for select to authenticated
      using (bucket_id = 'tenant-logos' and (select public.is_super_admin()))
  $p$;
  execute $p$
    create policy "super admin uploads tenant logos" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'tenant-logos' and (select public.is_super_admin()))
  $p$;
  execute $p$
    create policy "super admin updates tenant logos" on storage.objects
      for update to authenticated
      using (bucket_id = 'tenant-logos' and (select public.is_super_admin()))
      with check (bucket_id = 'tenant-logos' and (select public.is_super_admin()))
  $p$;
  execute $p$
    create policy "super admin deletes tenant logos" on storage.objects
      for delete to authenticated
      using (bucket_id = 'tenant-logos' and (select public.is_super_admin()))
  $p$;
end;
$$;
