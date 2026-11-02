-- =====================================================================
-- Kurum lisansı bitince öğrenci, koç ve veli erişimi de biter
-- ---------------------------------------------------------------------
--  * Önceden license_expires_at yalnızca yeni kaydı engelliyordu; kayıtlı
--    kullanıcılar lisans bittikten sonra da her şeyi kullanabiliyordu.
--  * my_license_active(): kullanıcının kurumunun lisansı geçerli mi. Müdür
--    her zaman true (lisansın bittiğini panelinde görsün); kurumu olmayan
--    (platform yöneticisi) ve süresiz lisanslı kurumlar da true.
--  * my_tenant_active() artık lisansı da kontrol eder. Tüm "tenant
--    isolation" politikaları ve SECURITY DEFINER RPC'ler bunu kullandığı
--    için lisansı biten kurumun öğrenci, koç ve velisi hiçbir veriye
--    erişemez; yalnızca kendi profilini okur (uygulama bu sayede "lisans
--    doldu" ekranını gösterir). Lisans uzatılınca erişim kendiliğinden döner.
--
-- Geri almak için: supabase/rollbacks/20261031110000_license_access.down.sql
-- =====================================================================

create or replace function public.my_license_active()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce((
    select p.role = 'admin'
           or o.license_expires_at is null
           or o.license_expires_at > now()
    from public.profiles p
    join public.organizations o on o.id = p.org_id
    where p.id = auth.uid()), true)
$$;
revoke execute on function public.my_license_active() from public, anon;
grant execute on function public.my_license_active() to authenticated;

create or replace function public.my_tenant_active()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce((select t.is_active from public.tenants t
                   where t.id = public.my_tenant()), false)
         and public.my_license_active()
$$;

-- Lisansı biten kurumda koç / öğrenci yeni davet kodu üretemez (create_invite
-- SECURITY DEFINER olduğu için RLS'ye takılmıyordu). Müdür etkilenmez.
create or replace function public.guard_invite_license()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.my_license_active() then
    raise exception 'LICENSE_EXPIRED';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_invite_license() from public, anon, authenticated;

create trigger guard_invite_license before insert on public.invite_codes
  for each row execute function public.guard_invite_license();
