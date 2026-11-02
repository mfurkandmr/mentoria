-- =====================================================================
-- Otomatik konu reçetesi
-- ---------------------------------------------------------------------
-- Deneme analizinden eksik kazanımlar → haftalık ödev taslağı. Öğretmen
-- taslağı uygulamada görür, maddeleri seçer / soru sayısını değiştirir ve
-- tek tuşla mevcut ödev akışıyla (assignments) gönderir. Burada yalnızca
-- öneri hesaplanır; hiçbir şey yazılmaz.
--
--  * topic_prescription(öğrenci, son kaç deneme = 3): son denemelerin
--    exam_wrong_topics kayıtlarından konu başına yanlış sayısı ve kaç
--    denemede yanlış yapıldığı. Optikten okunan denemelerde kazanım metinleri
--    (exam_answers.outcome, en çok 2) de gelir.
--  * Son 14 günde zaten ödev verilmiş konular çıkarılır.
--  * Önerilen soru: 1 yanlış → 15, 2-3 → 25, 4+ → 40. En çok 8 konu; önce
--    birden çok denemede tekrar eden, sonra en çok yanlış.
--  * Yalnızca öğrencinin koçu ve kurum müdürü çağırabilir.
--
-- Geri almak için: supabase/rollbacks/20261031150000_topic_prescription.down.sql
-- =====================================================================

create or replace function public.topic_prescription(
  p_student uuid, p_exams int default 3)
returns table (
  subject_code text,
  topic_id     int,
  topic_name   text,
  wrong        int,
  exam_count   int,
  outcomes     text[],
  suggested    int
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.can_manage_student(p_student) or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  return query
  with recent as (
    select e.id from public.exams e
    where e.student_id = p_student
    order by e.taken_on desc, e.created_at desc
    limit least(greatest(coalesce(p_exams, 3), 1), 10)
  ), w as (
    -- Sütun adları dönüş sütunlarıyla çakışmasın diye kısa adlar.
    select wt.topic_id as tid, sum(wt.count)::int as n_wrong,
           count(distinct wt.exam_id)::int as n_exams
    from public.exam_wrong_topics wt
    where wt.exam_id in (select id from recent)
    group by wt.topic_id
  ), assigned as (
    select ai.topic_id as tid from public.assignment_items ai
    join public.assignments a on a.id = ai.assignment_id
    where a.student_id = p_student and ai.topic_id is not null
      and a.created_at > now() - interval '14 days'
  )
  select s.code, t.id, t.name, w.n_wrong, w.n_exams,
         coalesce((
           select (array_agg(distinct ea.outcome))[1:2]
           from public.exam_answers ea
           where ea.exam_id in (select id from recent)
             and ea.topic_id = t.id
             and ea.outcome is not null
             and ea.correct is not null
             and ea.marked is distinct from ea.correct
         ), '{}'),
         case when w.n_wrong >= 4 then 40 when w.n_wrong >= 2 then 25 else 15 end
  from w
  join public.topics t on t.id = w.tid
  join public.subjects s on s.id = t.subject_id
  where w.tid not in (select tid from assigned)
  order by w.n_exams desc, w.n_wrong desc, s.sort, t.sort
  limit 8;
end;
$$;
revoke execute on function public.topic_prescription(uuid, int) from public, anon;
grant execute on function public.topic_prescription(uuid, int) to authenticated;
