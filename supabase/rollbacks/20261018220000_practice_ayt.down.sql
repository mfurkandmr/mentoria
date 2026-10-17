-- Geri alma: 20261018220000_practice_ayt (AYT cevapları silinir)
delete from public.practice_answers where subject_code like 'AYT\_%';

alter table public.practice_answers drop constraint if exists practice_answers_subject_code_check;
alter table public.practice_answers add constraint practice_answers_subject_code_check
  check (subject_code in (
    'TYT_TUR', 'TYT_MAT', 'TYT_FIZ', 'TYT_KIM', 'TYT_BIY',
    'TYT_TAR', 'TYT_COG', 'TYT_FEL', 'TYT_DIN'));

alter table public.practice_answers drop constraint if exists practice_answers_question_id_check;
alter table public.practice_answers add constraint practice_answers_question_id_check
  check (question_id ~ '^TYT_[A-Z]{3}-[0-9]{4}$');

create or replace function public.practice_daily_limit(p_subject text)
returns int
language sql immutable set search_path = ''
as $$
  select case when p_subject in ('TYT_TUR', 'TYT_MAT') then 20 else 10 end
$$;
