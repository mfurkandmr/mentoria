-- Geri alma: 20261031120000_weekly_summary
-- send_parent_weekly_reports 20261018190000_mistakes_and_parent_report sürümüne
-- döner (aşağıdaki oradan aynen kopya).
drop function if exists public.weekly_summary(uuid);
drop function if exists public.weekly_summary_data(uuid, timestamptz);

-- Her veliye, her çocuğu için son 7 günün özeti (haftada bir).
create or replace function public.send_parent_weekly_reports(p_now timestamptz default now())
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_end   date := (p_now at time zone 'Europe/Istanbul')::date;
  v_start date := v_end - 6;
  v_n int;
begin
  insert into public.notifications (user_id, kind, data, ref_id)
  select ps.parent_id, 'weekly_report',
         jsonb_build_object(
           'child', split_part(s.full_name, ' ', 1),
           'child_id', ps.student_id,
           'questions', coalesce(q.total, 0),
           'minutes', coalesce(m.minutes, 0),
           'days', coalesce(d.days, 0),
           'route', '/parent/child/' || ps.student_id || '?tab=4'),
         ps.student_id
  from public.parent_students ps
  join public.profiles s on s.id = ps.student_id
  join public.tenants t on t.id = s.tenant_id and t.is_active
  left join lateral (
    select sum(correct + wrong + blank)::int total
    from public.question_logs
    where student_id = ps.student_id and logged_on between v_start and v_end
  ) q on true
  left join lateral (
    select (sum(duration_sec) / 60)::int minutes
    from public.study_sessions
    where student_id = ps.student_id
      and (started_at at time zone 'Europe/Istanbul')::date between v_start and v_end
  ) m on true
  left join lateral (
    select count(distinct active_day)::int days from (
      select logged_on as active_day from public.question_logs
      where student_id = ps.student_id and logged_on between v_start and v_end
        and correct + wrong + blank > 0
      union
      select (started_at at time zone 'Europe/Istanbul')::date from public.study_sessions
      where student_id = ps.student_id
        and (started_at at time zone 'Europe/Istanbul')::date between v_start and v_end
    ) x
  ) d on true
  where not exists (
    select 1 from public.notifications n
    where n.user_id = ps.parent_id and n.kind = 'weekly_report'
      and n.ref_id = ps.student_id
      and n.created_at > p_now - interval '5 days');
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.send_parent_weekly_reports(timestamptz) from public, anon, authenticated;
