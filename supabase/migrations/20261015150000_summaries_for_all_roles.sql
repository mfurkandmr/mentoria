-- =====================================================================
-- Koç ve kurum müdürü için ortak öğrenci özeti
--  * coach_student_summaries() yerine student_summaries():
--    çağıran kişinin yönetebildiği tüm öğrenciler (koç → kendi öğrencileri,
--    müdür → kurumdaki tüm öğrenciler)
--  * Haftalık soru, haftalık çalışma dakikası, bekleyen görev sayısı
-- =====================================================================

drop function public.coach_student_summaries();

create or replace function public.student_summaries()
returns table (
  student_id      uuid,
  full_name       text,
  student_number  text,
  coach_id        uuid,
  coach_name      text,
  exam_count      int,
  last_exam_name  text,
  last_exam_type  public.exam_type,
  last_total_net  numeric,
  last_taken_on   date,
  week_questions  int,
  week_minutes    int,
  pending_tasks   int
)
language sql stable security invoker set search_path = ''
as $$
  select p.id,
         p.full_name,
         p.student_number,
         cs.coach_id,
         c.full_name,
         (select count(*)::int from public.exams e where e.student_id = p.id),
         le.name,
         le.exam_type,
         le.total_net,
         le.taken_on,
         (select coalesce(sum(q.correct + q.wrong + q.blank), 0)::int
          from public.question_logs q
          where q.student_id = p.id and q.logged_on > current_date - 7),
         (select (coalesce(sum(s.duration_sec), 0) / 60)::int
          from public.study_sessions s
          where s.student_id = p.id and s.started_at > now() - interval '7 days'),
         (select count(*)::int from public.tasks t
          where t.student_id = p.id and t.status = 'pending')
  from public.profiles p
  left join public.coach_students cs on cs.student_id = p.id
  left join public.profiles c on c.id = cs.coach_id
  left join lateral (
    select e.name, e.exam_type, e.taken_on,
           (select coalesce(sum(r.net), 0)
            from public.exam_subject_results r
            where r.exam_id = e.id) as total_net
    from public.exams e
    where e.student_id = p.id
    order by e.taken_on desc, e.created_at desc
    limit 1
  ) le on true
  where p.role = 'student'
    and public.can_manage_student(p.id)
  order by p.full_name
$$;

revoke execute on function public.student_summaries() from public, anon;
grant  execute on function public.student_summaries() to authenticated;
