-- =====================================================================
-- Performans geçişi (NOTLAR §73)
-- ---------------------------------------------------------------------
-- Sonuçlar değişmez; aynı veri daha az işle gelir.
--  * Eksik index'ler: kurum sınavı (batch_id), deneme eğilimleri, bildirim
--    silme (kind/ref_id) ve danışmanın işaretlediği 13 yabancı anahtar.
--  * Başka index'in zaten kapsadığı iki index kaldırıldı (yazma maliyeti).
--  * student_summaries: satır başına RLS yerine SECURITY DEFINER. Öğrenci
--    kümesi my_managed_students() ile zaten süzülüyor; RLS'in sağladığı
--    öteki üç kural sorguda açıkça yazılı (dershane, lisans, koç bağı).
--  * weekly_summary_data: tarih süzgeci index'i kullanacak biçimde.
--  * activity_weeks: hafta başına üç tarama yerine tek geçiş.
--  * cron.job_run_details: hiç temizlenmiyordu (veritabanının yarısı);
--    artık 7 günden eskisi gece siliniyor.
--
-- Geri almak için: supabase/rollbacks/20261109120000_performance_pass.down.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- Index'ler
-- ---------------------------------------------------------------------
create index exams_batch_id_source_idx on public.exams (batch_id, source)
  where batch_id is not null;
create index exams_student_type_recent_idx
  on public.exams (student_id, exam_type, taken_on desc, created_at desc);
create index notifications_kind_ref_id_idx on public.notifications (kind, ref_id)
  where ref_id is not null;

create index rooms_tenant_id_idx on public.rooms (tenant_id);
create index teachers_tenant_id_idx on public.teachers (tenant_id);
create index teacher_availability_tenant_id_idx on public.teacher_availability (tenant_id);
create index classrooms_tenant_id_idx on public.classrooms (tenant_id);
create index classroom_students_tenant_id_idx on public.classroom_students (tenant_id);
create index time_slots_tenant_id_idx on public.time_slots (tenant_id);
create index class_lessons_tenant_id_idx on public.class_lessons (tenant_id);
create index schedules_tenant_id_idx on public.schedules (tenant_id);
create index schedule_entries_tenant_id_idx on public.schedule_entries (tenant_id);
create index learning_outcomes_subject_id_idx on public.learning_outcomes (subject_id);
create index answer_key_subjects_subject_id_idx on public.answer_key_subjects (subject_id);
create index answer_key_booklets_subject_id_idx on public.answer_key_booklets (subject_id);
create index org_exam_plans_created_by_idx on public.org_exam_plans (created_by);

-- Kapsayanları: (subject_id, question_no) ve (created_by, batch_id).
drop index if exists public.exam_answers_subject_id_idx;
drop index if exists public.exams_created_by_idx;

-- ---------------------------------------------------------------------
-- Koç/müdür öğrenci listesi
-- ---------------------------------------------------------------------
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
language sql stable security definer set search_path = ''
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
  -- "read coach links" kuralı: koç yalnızca kendi bağını, müdür kurumunu görür.
  -- Yoksa iki koçlu öğrenci koçun listesinde iki kez çıkardı.
  left join public.coach_students cs on cs.student_id = p.id
    and (cs.coach_id = (select auth.uid())
         or (cs.org_id = (select public.my_org())
             and (select public.my_role()) = 'admin'))
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
    -- RLS'in kısıtlayıcı dershane/lisans kuralları.
    and p.tenant_id = (select public.my_tenant())
    and (select public.my_tenant_active())
  order by p.full_name
$$;
revoke execute on function public.student_summaries() from public, anon;
grant  execute on function public.student_summaries() to authenticated;

-- ---------------------------------------------------------------------
-- Haftalık özet: my_risk_list her öğrenci için çağırır
-- ---------------------------------------------------------------------
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
      and s.started_at >= (b.d_start::timestamp at time zone 'Europe/Istanbul')
      and s.started_at < ((b.d_end + 1)::timestamp at time zone 'Europe/Istanbul')
  ), d as (
    select count(distinct x.day)::int as days from (
      select l.logged_on as day from public.question_logs l, bounds b
      where l.student_id = p_student and l.logged_on between b.d_start and b.d_end
        and l.correct + l.wrong + l.blank > 0
      union
      select (s.started_at at time zone 'Europe/Istanbul')::date
      from public.study_sessions s, bounds b
      where s.student_id = p_student
        and s.started_at >= (b.d_start::timestamp at time zone 'Europe/Istanbul')
        and s.started_at < ((b.d_end + 1)::timestamp at time zone 'Europe/Istanbul')
    ) x
  ), mt as (
    select count(*) filter (where o.status = 'held')::int as held,
           count(*) filter (where o.status = 'missed')::int as missed
    from public.meeting_occurrences o, bounds b
    where o.student_id = p_student and o.occurs_on between b.d_start and b.d_end
  ), hw as (
    -- Bu hafta teslim günü olan (teslim günü yoksa bu hafta verilen) ödevler.
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

-- ---------------------------------------------------------------------
-- Kokpit eğilim grafiği: tarih aralığı tek geçişte haftalara bölünür
-- ---------------------------------------------------------------------
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
  ),
  ql as (
    select q.student_id,
           (current_date - q.logged_on) / 7 as k,
           q.correct + q.wrong + q.blank as solved
      from public.question_logs q
      join st on st.id = q.student_id, n
     where q.logged_on between current_date - 7 * n.weeks + 1 and current_date
  ),
  ss as (
    select s.student_id,
           (current_date - s.started_at::date) / 7 as k
      from public.study_sessions s
      join st on st.id = s.student_id, n
     where s.started_at >= current_date - 7 * n.weeks + 1
       and s.started_at < current_date + 1
  ),
  active as (
    select x.k, count(*) as c
      from (select student_id, k from ql union select student_id, k from ss) x
     group by x.k
  ),
  solved as (
    select ql.k, sum(ql.solved) as c from ql group by ql.k
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'start', w.d0,
           'end', w.d1,
           'students', (select count(*) from st where st.created_at::date <= w.d1),
           'active', coalesce(a.c, 0),
           'questions', coalesce(q.c, 0))
         order by w.d0), '[]'::jsonb)
    from w
    left join active a on a.k = w.k
    left join solved q on q.k = w.k
$$;
revoke all on function public.activity_weeks(int) from public, anon;
grant execute on function public.activity_weeks(int) to authenticated;

-- ---------------------------------------------------------------------
-- pg_cron geçmişi (15 saniyelik iş yüzünden günde ~6.000 satır)
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    perform cron.schedule('purge-cron-history', '15 1 * * *',
      $job$delete from cron.job_run_details where end_time < now() - interval '7 days'$job$);
    delete from cron.job_run_details where end_time < now() - interval '7 days';
  else
    raise notice 'pg_cron yok (yerel test ortamı); zamanlanmadı';
  end if;
end;
$$;
