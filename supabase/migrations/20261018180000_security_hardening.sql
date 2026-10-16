-- =====================================================================
-- Güvenlik sıkılaştırması (canlıya çıkış öncesi denetim, 17 Ekim 2026)
-- ---------------------------------------------------------------------
-- 1. Giriş yapmamış istemci (anon) hiçbir tabloya doğrudan erişemez.
--    Zaten hiçbir politika anon'a satır göstermiyordu; artık izin de yok
--    (RLS'te bir hata olsa bile ikinci kilit). anon'un ihtiyacı olan iki
--    şey RPC: check_invite (davet kodu) ve tenant_branding (dershane linki).
-- 2. TRUNCATE / TRIGGER / REFERENCES hiçbir istemci rolünde yok: TRUNCATE
--    RLS'e takılmaz, istemcinin bunlara hiç ihtiyacı yok.
-- 3. Yeni oluşturulacak tablolar da varsayılan olarak anon'a açılmaz.
-- 4. Tetikleyici fonksiyonu handle_user_email_confirmed dışarıdan
--    çağrılamaz.
-- 5. Dershane logosu yalnızca bu projenin Storage'ındaki kendi klasöründen
--    olabilir. Eski denetim adresin SONUNA bakıyordu; başka bir sunucudaki
--    ".../storage/v1/object/public/tenant-logos/<id>/..." yolu geçiyordu ve
--    o sunucu her öğrencinin IP adresini görebilirdi.
-- 6. profiles.avatar_url uygulamada kullanılmıyor: istemci yazamaz
--    (keyfi bir adres başka kullanıcılara izleme pikseli olabilirdi).
-- 7. Soru kaydı başına üst sınır (1.500): sıralamayı uydurma sayılarla
--    şişirmek engellenir.
--
-- Geri almak için: supabase/rollbacks/20261018180000_security_hardening.down.sql
-- =====================================================================

-- 1–2. Tablo izinleri
revoke all on all tables in schema public from anon;
revoke truncate, trigger, references on all tables in schema public from authenticated;

-- 3. Sonradan oluşturulacak tablolar
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke truncate, trigger, references on tables from authenticated;

-- 4. Tetikleyici fonksiyonu
revoke all on function public.handle_user_email_confirmed() from public, anon, authenticated;

-- 5. Logo adresi
alter table public.tenants drop constraint if exists tenants_logo_url_check;
alter table public.tenants add constraint tenants_logo_url_check check (
  logo_url is null
  or logo_url ~ '^https://[a-z0-9.-]+/storage/v1/object/public/tenant-logos/[A-Za-z0-9/._-]+$'
);

-- Logo için izin verilen tam adres öneki: bu projenin Storage'ı, dershanenin
-- kendi klasörü. Proje adresi Vault'taki push_function_url'den okunur
-- (yoksa yalnızca *.supabase.co biçimi denetlenir).
create or replace function public.logo_url_allowed(p_url text, p_tenant uuid)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_host text;
  v_fn   text;
begin
  if p_url is null then
    return true;
  end if;
  v_host := substring(p_url from '^https://([a-z0-9-]+\.supabase\.co)/');
  if v_host is null
     or p_url !~ ('^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/public/tenant-logos/'
                  || p_tenant::text || '/[A-Za-z0-9._-]+$') then
    return false;
  end if;
  if to_regclass('vault.decrypted_secrets') is not null then
    execute $q$select decrypted_secret from vault.decrypted_secrets
               where name = 'push_function_url' limit 1$q$ into v_fn;
    if v_fn is not null and v_fn !~ ('^https://' || replace(v_host, '.', '\.') || '/') then
      return false;
    end if;
  end if;
  return true;
end;
$$;
revoke all on function public.logo_url_allowed(text, uuid) from public, anon, authenticated;

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
  -- Logo yalnızca bu projenin Storage'ında, bu dershanenin klasöründen.
  if not public.logo_url_allowed(v_logo, v_tenant) then
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

-- 6. Kullanılmayan avatar_url
revoke update (avatar_url) on public.profiles from authenticated;

-- 7. Soru kaydı üst sınırı
alter table public.question_logs
  add constraint question_logs_total_check check (correct + wrong + blank <= 1500);
