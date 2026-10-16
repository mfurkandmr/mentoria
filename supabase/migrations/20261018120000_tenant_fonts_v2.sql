-- =====================================================================
-- Kurum yazı tipleri: yeni liste
--
-- İlk listedeki yazı tiplerinin çoğu birbirine çok benziyordu (hepsi sade
-- sans-serif). Yeni listede her biri ayrı bir tarz: yuvarlak, geometrik,
-- klasik tırnaklı, zarif, kalın tırnaklı, dar, tombul, el yazısı, daktilo,
-- fütüristik. (lib/core/theme/app_fonts.dart ile aynı liste.)
--  * Listeden çıkan yazı tipini seçmiş dershane Nunito'ya döner.
--  * update_my_branding yeni listeyi denetler (imza aynı).
--
-- Geri almak için: supabase/rollbacks/20261018120000_tenant_fonts_v2.down.sql
-- =====================================================================

alter table public.tenants drop constraint tenants_font_family_check;

update public.tenants
set font_family = 'nunito'
where font_family not in (
  'nunito', 'poppins', 'merriweather', 'playfair_display', 'roboto_slab',
  'oswald', 'baloo_2', 'patrick_hand', 'space_mono', 'exo_2');

alter table public.tenants add constraint tenants_font_family_check
  check (font_family in (
    'nunito', 'poppins', 'merriweather', 'playfair_display', 'roboto_slab',
    'oswald', 'baloo_2', 'patrick_hand', 'space_mono', 'exo_2'));

create or replace function public.update_my_branding(
  p_name            text,
  p_primary_color   text,
  p_secondary_color text,
  p_logo_url        text default null,
  p_font_family     text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_tenant uuid := public.my_tenant();
  v_logo   text := nullif(trim(p_logo_url), '');
  v_font   text := nullif(lower(trim(p_font_family)), '');
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
  if v_font is not null and v_font not in (
       'nunito', 'poppins', 'merriweather', 'playfair_display', 'roboto_slab',
       'oswald', 'baloo_2', 'patrick_hand', 'space_mono', 'exo_2') then
    raise exception 'INVALID_FONT';
  end if;

  update public.tenants
  set name = left(trim(p_name), 80),
      primary_color = upper(p_primary_color),
      secondary_color = upper(p_secondary_color),
      logo_url = v_logo,
      font_family = coalesce(v_font, font_family)
  where id = v_tenant;

  -- Tek kurumlu dershanede kurum adı da aynı olsun.
  if (select count(*) from public.organizations where tenant_id = v_tenant) = 1 then
    update public.organizations
    set name = left(trim(p_name), 80)
    where tenant_id = v_tenant and name is distinct from left(trim(p_name), 80);
  end if;
end;
$$;
