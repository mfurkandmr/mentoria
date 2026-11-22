-- =====================================================================
-- Maarif Modeli müfredatı (NOTLAR §104)
-- ---------------------------------------------------------------------
-- Türkiye Yüzyılı Maarif Modeli konuları, eski müfredatla yan yana yaşar:
--  * topics.curriculum   'eski' (varsayılan, bugünkü liste) | 'maarif'
--  * topics.grade        Maarif konusunun sınıfı (9-12); eski konularda boş
--  * topics.group_name   Maarif temasının / ünitesinin adı
--  * topics.source_url   MEB öğretim programı sayfası (kaynak)
--  * profiles.curriculum öğrencinin müfredatı; boşsa uygulama sınıftan
--                        türetir (9-11 → maarif, 12 / mezun → eski)
--  * set_curriculum(öğrenci, müfredat): öğrencinin kendisi ya da onu yöneten
--    koç / müdür değiştirir; doğrudan güncelleme kapalı.
-- Konu verisi: supabase/seed_maarif_topics.sql (tool/maarif/build_seed.py).
--
-- Geri almak için: supabase/rollbacks/20261121110000_maarif_curriculum.down.sql
-- =====================================================================

alter table public.topics
  add column if not exists curriculum text not null default 'eski'
    check (curriculum in ('eski', 'maarif')),
  add column if not exists grade smallint check (grade between 9 and 12),
  add column if not exists group_name text,
  add column if not exists source_url text;

-- Maarif konusu sınıfsız olamaz; eski konunun sınıfı olmaz.
alter table public.topics
  add constraint topics_curriculum_grade
  check ((curriculum = 'maarif') = (grade is not null));

create unique index if not exists topics_maarif_unique
  on public.topics (subject_id, grade, name) where curriculum = 'maarif';
create index if not exists topics_curriculum_grade_idx
  on public.topics (curriculum, grade);

alter table public.profiles
  add column if not exists curriculum text
    check (curriculum in ('eski', 'maarif'));

create or replace function public.set_curriculum(p_student uuid, p_curriculum text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if p_curriculum is not null and p_curriculum not in ('eski', 'maarif') then
    raise exception 'BAD_CURRICULUM';
  end if;
  if not exists (select 1 from public.profiles where id = p_student and role = 'student')
     or (p_student <> auth.uid() and not public.can_manage_student(p_student)) then
    raise exception 'NOT_ALLOWED';
  end if;
  update public.profiles set curriculum = p_curriculum where id = p_student;
end;
$$;
revoke all on function public.set_curriculum(uuid, text) from public, anon;
grant execute on function public.set_curriculum(uuid, text) to authenticated;
