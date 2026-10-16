-- =====================================================================
-- Kurum yazı tipi
--
-- Kurum müdürü markasının parçası olarak 10 yazı tipinden birini seçer;
-- dershanedeki herkes (müdür, koç, öğrenci, veli) uygulamayı o yazı tipiyle
-- görür. Yazı tipleri uygulamada Google Fonts'tan yüklenir; burada yalnızca
-- anahtarı tutulur (lib/core/theme/app_fonts.dart ile aynı liste).
--  * tenants.font_family (varsayılan 'nunito': mevcut görünüm değişmez).
--  * tenant_branding ve check_invite yazı tipini de döndürür (giriş ve
--    davetle kayıt ekranı da kurumun yazı tipiyle açılır).
--  * update_my_branding'e p_font_family eklendi (null: değiştirme).
--  * Süper admin tenants tablosunu doğrudan günceller (mevcut politika).
--
-- Geri almak için: supabase/rollbacks/20261018110000_tenant_fonts.down.sql
-- =====================================================================

alter table public.tenants
  add column font_family text not null default 'nunito'
  constraint tenants_font_family_check check (font_family in (
    'nunito', 'poppins', 'montserrat', 'inter', 'roboto',
    'open_sans', 'lato', 'plus_jakarta_sans', 'quicksand', 'raleway'));

create or replace function public.tenant_branding(p_slug text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
           'id', t.id, 'name', t.name, 'slug', t.slug, 'logo_url', t.logo_url,
           'primary_color', t.primary_color, 'secondary_color', t.secondary_color,
           'font_family', t.font_family, 'is_active', t.is_active)
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
             'font_family', t.font_family,
             'is_active', t.is_active))
  from public.invite_codes i
  join public.organizations o on o.id = i.org_id
  join public.tenants t on t.id = o.tenant_id
  where i.code = upper(trim(p_code))
    and i.expires_at > now()
    and i.used_count < i.max_uses
    and t.is_active
$$;

-- İmza değiştiği için eski sürüm kaldırılır (aynı adla iki fonksiyon olmasın).
drop function public.update_my_branding(text, text, text, text);
create function public.update_my_branding(
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
       'nunito', 'poppins', 'montserrat', 'inter', 'roboto',
       'open_sans', 'lato', 'plus_jakarta_sans', 'quicksand', 'raleway') then
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
revoke execute on function public.update_my_branding(text, text, text, text, text) from public, anon;
grant  execute on function public.update_my_branding(text, text, text, text, text) to authenticated;
