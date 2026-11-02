-- Geri alma: 20261030100000_optic_reading
-- Optikten okunan denemeler (source = 'optic') kalır ama 'import' sayılır;
-- soru soru cevapları ve anahtarlar silinir.
drop function if exists public.submit_optic(uuid, uuid, jsonb);
drop function if exists public.delete_answer_key(uuid);
drop function if exists public.create_answer_key(text, public.exam_type, text, date, text, jsonb);
drop table if exists public.exam_answers;
drop table if exists public.answer_key_items;
drop table if exists public.answer_keys;

update public.exams set source = 'import' where source = 'optic';
alter table public.exams drop constraint if exists exams_source_check;
alter table public.exams add constraint exams_source_check
  check (source in ('manual', 'import'));
