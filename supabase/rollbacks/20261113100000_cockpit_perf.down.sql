-- 20261113100000_cockpit_perf geri alma: 20261106160000 sürümüne döner
-- (net_drops kendiyle birleştirme ile hesaplanır; daha yavaş ama aynı sonuç).
create or replace function public.admin_cockpit()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_org   uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  v_week  date := date_trunc('week', current_date)::date;
  v_out   jsonb;
begin
  if v_org is null then
    raise exception 'COCKPIT_NOT_ADMIN';
  end if;

  with st as (
    select p.id, p.full_name, p.created_at, p.last_seen_at,
           cs.coach_id, c.full_name as coach_name
      from public.profiles p
      left join public.coach_students cs on cs.student_id = p.id
      left join public.profiles c on c.id = cs.coach_id
     where p.org_id = v_org and p.role = 'student'
  ),
  q as (
    select q.student_id,
           sum(q.correct + q.wrong + q.blank) filter (where q.logged_on > current_date - 7) as now_q,
           sum(q.correct + q.wrong + q.blank) filter (where q.logged_on <= current_date - 7) as prev_q,
           max(q.created_at) as last_at
      from public.question_logs q
     where q.student_id in (select id from st) and q.logged_on > current_date - 14
     group by q.student_id
  ),
  s as (
    select s.student_id,
           sum(s.duration_sec) filter (where s.started_at > now() - interval '7 days') / 60 as now_m,
           sum(s.duration_sec) filter (where s.started_at <= now() - interval '7 days') / 60 as prev_m,
           max(s.started_at) as last_at
      from public.study_sessions s
     where s.student_id in (select id from st) and s.started_at > now() - interval '14 days'
     group by s.student_id
  ),
  act as (
    select st.*,
           coalesce(q.now_q, 0) as now_q, coalesce(q.prev_q, 0) as prev_q,
           coalesce(s.now_m, 0) as now_m, coalesce(s.prev_m, 0) as prev_m,
           (coalesce(q.now_q, 0) > 0 or coalesce(s.now_m, 0) > 0) as active_now,
           (coalesce(q.prev_q, 0) > 0 or coalesce(s.prev_m, 0) > 0) as active_prev,
           greatest(st.last_seen_at, q.last_at, s.last_at) as seen_at
      from st
      left join q on q.student_id = st.id
      left join s on s.student_id = st.id
  ),
  ex as (
    select e.student_id, e.exam_type, e.taken_on,
           (select coalesce(sum(r.net), 0) from public.exam_subject_results r where r.exam_id = e.id) as net,
           row_number() over (partition by e.student_id, e.exam_type
                              order by e.taken_on desc, e.created_at desc) as rn,
           first_value(e.exam_type) over (partition by e.student_id
                                          order by e.taken_on desc, e.created_at desc) as latest_type
      from public.exams e
     where e.student_id in (select id from st)
  ),
  drops as (
    select a.student_id, a.exam_type, a.net as last_net, b.net as prev_net, a.taken_on
      from ex a
      join ex b on b.student_id = a.student_id and b.exam_type = a.exam_type and b.rn = 2
     where a.rn = 1 and a.exam_type = a.latest_type
       and a.taken_on > current_date - 45
       and b.net - a.net >= 3
  ),
  late as (
    select f.student_id,
           count(*) as cnt,
           sum(i.amount - i.paid_amount) as amount,
           min(i.due_on) as oldest
      from public.finance_installments i
      join public.finance_fees f on f.id = i.fee_id
     where f.org_id = v_org and f.status = 'active'
       and i.paid_on is null and i.due_on < current_date
       and i.amount - i.paid_amount > 0.005
     group by f.student_id
  ),
  days as (
    select (v_week + g)::date as d from generate_series(0, 6) g
  ),
  meet as (
    select ms.coach_id,
           count(*) filter (where coalesce(mo.status, '') <> 'cancelled') as planned,
           count(*) filter (where mo.status = 'held') as held
      from public.meeting_schedules ms
      join public.profiles sp on sp.id = ms.student_id and sp.org_id = v_org
      join days on public.meeting_occurs_on(ms.first_date, ms.repeat_weekly, ms.until_date, days.d)
      left join public.meeting_occurrences mo
             on mo.schedule_id = ms.id and mo.occurs_on = days.d
     group by ms.coach_id
  )
  select jsonb_build_object(
    'students', (select count(*) from act),
    'students_prev', (select count(*) from act where created_at <= now() - interval '7 days'),
    'active', (select count(*) from act where active_now),
    'active_prev', (select count(*) from act where active_prev),
    'questions', (select coalesce(sum(now_q), 0) from act),
    'questions_prev', (select coalesce(sum(prev_q), 0) from act),
    'minutes', (select coalesce(sum(now_m), 0) from act),
    'minutes_prev', (select coalesce(sum(prev_m), 0) from act),
    'exam_plans', coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'exam_type', x.exam_type,
                                          'planned_on', x.planned_on) order by x.planned_on, x.created_at)
        from (select * from public.org_exam_plans
               where org_id = v_org and planned_on >= current_date
               order by planned_on, created_at limit 20) x), '[]'::jsonb),
    'inactive', coalesce((
      select jsonb_agg(jsonb_build_object('student_id', a.id, 'full_name', a.full_name,
                                          'coach_id', a.coach_id, 'coach_name', a.coach_name,
                                          'seen_at', a.seen_at)
                       order by a.seen_at nulls first, a.full_name)
        from act a
       where a.created_at <= now() - interval '7 days'
         and (a.seen_at is null or a.seen_at < now() - interval '7 days')), '[]'::jsonb),
    'net_drops', coalesce((
      select jsonb_agg(jsonb_build_object('student_id', d.student_id, 'full_name', a.full_name,
                                          'coach_id', a.coach_id, 'coach_name', a.coach_name,
                                          'exam_type', d.exam_type, 'last_net', round(d.last_net, 2),
                                          'prev_net', round(d.prev_net, 2), 'taken_on', d.taken_on)
                       order by d.prev_net - d.last_net desc)
        from drops d join act a on a.id = d.student_id), '[]'::jsonb),
    'overdue', coalesce((
      select jsonb_agg(jsonb_build_object('student_id', l.student_id, 'full_name', a.full_name,
                                          'coach_id', a.coach_id, 'coach_name', a.coach_name,
                                          'count', l.cnt, 'amount', round(l.amount, 2),
                                          'oldest_due', l.oldest)
                       order by l.oldest, l.amount desc)
        from late l join act a on a.id = l.student_id), '[]'::jsonb),
    'coaches', coalesce((
      select jsonb_agg(jsonb_build_object(
               'coach_id', c.id, 'full_name', c.full_name, 'phone', cp.phone,
               'students', (select count(*) from act a where a.coach_id = c.id),
               'active', (select count(*) from act a where a.coach_id = c.id and a.active_now),
               'meetings_planned', coalesce(m.planned, 0),
               'meetings_held', coalesce(m.held, 0))
             order by c.full_name)
        from public.profiles c
        left join public.coach_phones cp on cp.coach_id = c.id
        left join meet m on m.coach_id = c.id
       where c.org_id = v_org and c.role = 'coach'), '[]'::jsonb)
  ) into v_out;
  return v_out;
end;
$$;
revoke all on function public.admin_cockpit() from public, anon;
grant execute on function public.admin_cockpit() to authenticated;
