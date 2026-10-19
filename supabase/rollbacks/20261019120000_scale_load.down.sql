-- Geri al: 20261019120000_scale_load.sql

-- 4. Koç / müdür panelleri: eski tanımlar
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

create or replace function public.exam_trends(p_exam_type text)
returns table (
  student_id  uuid,
  full_name   text,
  exam_count  int,
  first_net   numeric,
  last_net    numeric,
  delta       numeric,
  first_on    date,
  last_on     date
)
language sql stable security definer set search_path = ''
as $$
  with recent as (
    select e.student_id, e.taken_on,
           (select coalesce(sum(r.net), 0) from public.exam_subject_results r
            where r.exam_id = e.id) as net,
           row_number() over (partition by e.student_id
                              order by e.taken_on desc, e.created_at desc) as rn
    from public.exams e
    join public.profiles p on p.id = e.student_id
    where p.role = 'student'
      and e.exam_type::text = p_exam_type
      and public.my_tenant_active()
      and public.can_manage_student(e.student_id)
  ), last5 as (
    select * from recent where rn <= 5
  ), agg as (
    select l.student_id, count(*)::int as n,
           (array_agg(l.net order by l.rn desc))[1] as first_net,
           (array_agg(l.net order by l.rn))[1] as last_net,
           min(l.taken_on) as first_on, max(l.taken_on) as last_on
    from last5 l
    group by l.student_id
    having count(*) >= 2
  )
  select a.student_id, p.full_name, a.n, a.first_net, a.last_net,
         a.last_net - a.first_net, a.first_on, a.last_on
  from agg a
  join public.profiles p on p.id = a.student_id
  order by a.last_net - a.first_net desc
$$;
revoke execute on function public.exam_trends(text) from public, anon;
grant execute on function public.exam_trends(text) to authenticated;

drop function if exists public.my_managed_students();

-- 3. Push kuyruğu: her bildirim yine anında
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'drain-push-queue') then
      perform cron.unschedule('drain-push-queue');
    end if;
  end if;
end;
$$;

create or replace function public.push_on_notification()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_url    text;
  v_secret text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'push_function_url';
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_url is null or v_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret),
    body := jsonb_build_object('notification_id', new.id),
    timeout_milliseconds := 5000);
  return new;
exception when others then
  -- Bildirim gönderilemese de uygulama içi bildirim kaydı kalır.
  raise warning 'push_on_notification: %', sqlerrm;
  return new;
end;
$$;
revoke execute on function public.push_on_notification() from public, anon, authenticated;

drop function if exists public.drain_push_queue(int);
drop function if exists public.post_push(jsonb);
drop table if exists public.push_queue;
drop index if exists public.notifications_created_at_idx;

-- 2. Öğrenci ana sayfası
drop function if exists public.student_home(uuid, date, timestamptz);

-- 1. Realtime
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'notifications'
     ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;
