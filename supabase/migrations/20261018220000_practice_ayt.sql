-- =====================================================================
-- Eğitim: AYT dersleri
-- ---------------------------------------------------------------------
-- Soru havuzuna 11 AYT dersi eklendi (assets/learn/questions/AYT_*.json).
-- Günlük hak: AYT Matematik ve AYT Edebiyat 20, diğer AYT dersleri 10
-- (havuz = hak × 30). TYT hakları değişmedi.
--
-- Geri almak için: supabase/rollbacks/20261018220000_practice_ayt.down.sql
-- =====================================================================

alter table public.practice_answers drop constraint practice_answers_subject_code_check;
alter table public.practice_answers add constraint practice_answers_subject_code_check
  check (subject_code in (
    'TYT_TUR', 'TYT_MAT', 'TYT_FIZ', 'TYT_KIM', 'TYT_BIY', 'TYT_TAR', 'TYT_COG', 'TYT_FEL', 'TYT_DIN',
    'AYT_MAT', 'AYT_FIZ', 'AYT_KIM', 'AYT_BIY', 'AYT_EDB', 'AYT_TAR1', 'AYT_COG1', 'AYT_TAR2', 'AYT_COG2',
    'AYT_FELG', 'AYT_DIN'));

alter table public.practice_answers drop constraint practice_answers_question_id_check;
alter table public.practice_answers add constraint practice_answers_question_id_check
  check (question_id ~ '^(TYT|AYT)_[A-Z0-9]{3,4}-[0-9]{4}$');

create or replace function public.practice_daily_limit(p_subject text)
returns int
language sql immutable set search_path = ''
as $$
  select case when p_subject in ('TYT_TUR', 'TYT_MAT', 'AYT_MAT', 'AYT_EDB') then 20 else 10 end
$$;
