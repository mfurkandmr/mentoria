-- 20261121110000_maarif_curriculum geri alma.
-- Maarif konuları silinir (onlara bağlı ödev maddesi / konu ilerlemesi
-- kayıtları topics'e bağlı olduğundan önce temizlenmelidir).
drop function if exists public.set_curriculum(uuid, text);
alter table public.profiles drop column if exists curriculum;

delete from public.assignment_items where topic_id in
  (select id from public.topics where curriculum = 'maarif');
delete from public.topic_progress where topic_id in
  (select id from public.topics where curriculum = 'maarif');
delete from public.topics where curriculum = 'maarif';

drop index if exists public.topics_curriculum_grade_idx;
drop index if exists public.topics_maarif_unique;
alter table public.topics drop constraint if exists topics_curriculum_grade;
alter table public.topics
  drop column if exists source_url,
  drop column if exists group_name,
  drop column if exists grade,
  drop column if exists curriculum;
