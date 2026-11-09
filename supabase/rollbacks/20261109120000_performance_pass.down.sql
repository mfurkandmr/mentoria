-- 20261109120000_performance_pass geri alma: eski fonksiyonlar ve index'ler.

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('purge-cron-history');
  end if;
end;
$$;

create or replace function public.activity_weeks(p_weeks int default 8)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  with n as (
    select least(greatest(coalesce(p_weeks, 8), 1), 26) as weeks
  ),
  st as (
    select p.id, p.created_at
      from public.my_managed_students() m(id)
      join public.profiles p on p.id = m.id and p.role = 'student'
  ),
  w as (
    select g as k,
           current_date - 7 * (g + 1) + 1 as d0,
           current_date - 7 * g as d1
      from n, generate_series(0, n.weeks - 1) g
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'start', w.d0,
           'end', w.d1,
           'students', (select count(*) from st where st.created_at::date <= w.d1),
           'active', (
             select count(*) from (
               select q.student_id
                 from public.question_logs q
                where q.student_id in (select id from st)
                  and q.logged_on between w.d0 and w.d1
               union
               select s.student_id
                 from public.study_sessions s
                where s.student_id in (select id from st)
                  and s.started_at >= w.d0 and s.started_at < w.d1 + 1
             ) x),
           'questions', (
             select coalesce(sum(q.correct + q.wrong + q.blank), 0)
               from public.question_logs q
              where q.student_id in (select id from st)
                and q.logged_on between w.d0 and w.d1))
         order by w.d0), '[]'::jsonb)
    from w
$$;
revoke all on function public.activity_weeks(int) from public, anon;
grant execute on function public.activity_weeks(int) to authenticated;

create or replace function public.weekly_summary_data(
  p_student uuid, p_now timestamptz default now())
returns jsonb
language sql stable security definer set search_path = ''
as $$
  with bounds as (
    select (p_now at time zone 'Europe/Istanbul')::date as d_end,
           (p_now at time zone 'Europe/Istanbul')::date - 6 as d_start
  ), q as (
    select coalesce(sum(l.correct + l.wrong + l.blank), 0)::int as total
    from public.question_logs l, bounds b
    where l.student_id = p_student and l.logged_on between b.d_start and b.d_end
  ), m as (
    select coalesce(sum(s.duration_sec) / 60, 0)::int as minutes
    from public.study_sessions s, bounds b
    where s.student_id = p_student
      and (s.started_at at time zone 'Europe/Istanbul')::date between b.d_start and b.d_end
  ), d as (
    select count(distinct x.day)::int as days from (
      select l.logged_on as day from public.question_logs l, bounds b
      where l.student_id = p_student and l.logged_on between b.d_start and b.d_end
        and l.correct + l.wrong + l.blank > 0
      union
      select (s.started_at at time zone 'Europe/Istanbul')::date
      from public.study_sessions s, bounds b
      where s.student_id = p_student
        and (s.started_at at time zone 'Europe/Istanbul')::date between b.d_start and b.d_end
    ) x
  ), mt as (
    select count(*) filter (where o.status = 'held')::int as held,
           count(*) filter (where o.status = 'missed')::int as missed
    from public.meeting_occurrences o, bounds b
    where o.student_id = p_student and o.occurs_on between b.d_start and b.d_end
  ), hw as (
    select count(i.id)::int as total,
           count(i.id) filter (where i.done)::int as done
    from public.assignments a
    join public.assignment_items i on i.assignment_id = a.id, bounds b
    where a.student_id = p_student
      and coalesce(a.due_on, (a.created_at at time zone 'Europe/Istanbul')::date)
          between b.d_start and b.d_end
  ), ex as (
    select e.exam_type::text as exam_type, e.name, e.taken_on,
           (select coalesce(sum(r.net), 0) from public.exam_subject_results r
            where r.exam_id = e.id) as net,
           row_number() over (partition by e.exam_type
                              order by e.taken_on desc, e.created_at desc) as rn
    from public.exams e
    where e.student_id = p_student
  ), last_exam as (
    select * from ex where rn = 1 order by taken_on desc limit 1
  ), prev_exam as (
    select ex.net from ex join last_exam l on l.exam_type = ex.exam_type
    where ex.rn = 2
  )
  select jsonb_build_object(
    'from', b.d_start, 'to', b.d_end,
    'questions', q.total, 'minutes', m.minutes, 'days', d.days,
    'meetings_held', mt.held, 'meetings_missed', mt.missed,
    'homework_total', hw.total, 'homework_done', hw.done,
    'exam_type', le.exam_type, 'exam_name', le.name, 'exam_on', le.taken_on,
    'last_net', le.net, 'prev_net', (select net from prev_exam))
  from bounds b, q, m, d, mt, hw
  left join last_exam le on true
$$;
revoke all on function public.weekly_summary_data(uuid, timestamptz) from public, anon, authenticated;

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
  from public.my_managed_students() m(id)
  join public.profiles p on p.id = m.id
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
  order by p.full_name
$$;
revoke execute on function public.student_summaries() from public, anon;
grant  execute on function public.student_summaries() to authenticated;

create index if not exists exam_answers_subject_id_idx on public.exam_answers (subject_id);
create index if not exists exams_created_by_idx on public.exams (created_by);

drop index if exists public.exams_batch_id_source_idx;
drop index if exists public.exams_student_type_recent_idx;
drop index if exists public.notifications_kind_ref_id_idx;
drop index if exists public.rooms_tenant_id_idx;
drop index if exists public.teachers_tenant_id_idx;
drop index if exists public.teacher_availability_tenant_id_idx;
drop index if exists public.classrooms_tenant_id_idx;
drop index if exists public.classroom_students_tenant_id_idx;
drop index if exists public.time_slots_tenant_id_idx;
drop index if exists public.class_lessons_tenant_id_idx;
drop index if exists public.schedules_tenant_id_idx;
drop index if exists public.schedule_entries_tenant_id_idx;
drop index if exists public.learning_outcomes_subject_id_idx;
drop index if exists public.answer_key_subjects_subject_id_idx;
drop index if exists public.answer_key_booklets_subject_id_idx;
drop index if exists public.org_exam_plans_created_by_idx;
