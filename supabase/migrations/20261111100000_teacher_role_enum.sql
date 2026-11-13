-- =====================================================================
-- Öğretmen rolü (1/2): user_role'e 'teacher' değeri
-- ---------------------------------------------------------------------
-- PostgreSQL yeni enum değerinin aynı işlemde kullanılmasına izin vermez;
-- bu yüzden değer ayrı migration'da eklenir, kullanan kod
-- 20261111110000_teacher_role.sql'de.
--
-- Geri almak için: supabase/rollbacks/20261111100000_teacher_role_enum.down.sql
-- (enum değeri silinemez; dosya bunu açıklar.)
-- =====================================================================

alter type public.user_role add value if not exists 'teacher';
