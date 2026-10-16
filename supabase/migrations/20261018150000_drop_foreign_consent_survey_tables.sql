-- =====================================================================
-- Mentoria'ya ait olmayan tabloları kaldır
--
-- Canlı projeye 16 Ekim 2026'da depoda olmayan bir migration
-- (`create_consent_and_survey_tables`) uygulanmıştı: bir web sitesinin çerez
-- onayı ve anket kayıtları (IP, şehir, tarayıcı bilgisi). Uygulama bunları
-- kullanmıyordu; giriş yapan her kullanıcı okuyabiliyor, giriş yapmayan
-- herkes sınırsız satır ekleyebiliyordu.
--  * Yalnızca boşlarsa silinir; içlerinde kayıt varsa migration durur
--    (veri kaybı olmasın).
--  * Bu tabloların hiç olmadığı ortamlarda (yeni kurulum, testler) etkisizdir.
--
-- Geri almak için: supabase/rollbacks/20261018150000_drop_foreign_consent_survey_tables.down.sql
-- (tabloları canlıdaki ilk halleriyle yeniden oluşturur)
-- =====================================================================

-- Tablo yoksa adı hiç çözülmesin diye kontrol dinamik SQL ile yapılır.
do $$
declare
  t    text;
  v_has_rows boolean;
begin
  foreach t in array array['cookie_consents', 'survey_responses'] loop
    if to_regclass('public.' || t) is not null then
      execute format('select exists (select 1 from public.%I)', t) into v_has_rows;
      if v_has_rows then
        raise exception '% boş değil; silinmedi', t;
      end if;
    end if;
  end loop;
end;
$$;

drop table if exists public.cookie_consents;
drop table if exists public.survey_responses;
