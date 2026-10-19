-- Yük azaltma: deneme sonucu açıklanınca binlerce öğrenci aynı anda girince
-- Supabase zorlanmasın.
--   1. notifications Realtime yayınından çıkar (uygulama artık açılışta, öne
--      gelince ve push gelince tek sorguyla çekiyor; kalıcı bağlantı yok).
--   2. student_home(): öğrenci ana sayfasının verisi tek istekte.
--   3. Toplu bildirimlerin push'ları zamana yayılır (push_queue + pg_cron).
--   4. student_summaries() / exam_trends() yalnızca yönetilen öğrencileri gezer.
-- Geri almak için: supabase/rollbacks/20261019120000_scale_load.down.sql

-- 1. Realtime ------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime drop table public.notifications;
  end if;
end;
$$;

-- 2. Öğrenci ana sayfası --------------------------------------------------------
-- SECURITY INVOKER: satırlar çağıranın RLS'iyle süzülür; ayrı ayrı sorgu
-- atmakla aynı yetki, tek gidiş-dönüş. Alan adları uygulamanın PostgREST
-- sorgularıyla aynı biçimde (iç içe subjects/topics vb.) döner.
create or replace function public.student_home(
  p_student uuid,
  p_since date,
  p_since_ts timestamptz
) returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'logs', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', l.id,
          'correct', l.correct,
          'wrong', l.wrong,
          'blank', l.blank,
          'logged_on', l.logged_on,
          'source', l.source,
          'topic_id', l.topic_id,
          'subjects', jsonb_build_object('code', s.code),
          'topics', case when t.id is null then null
                         else jsonb_build_object('name', t.name) end
        ) order by l.logged_on desc, l.created_at desc)
      from question_logs l
      join subjects s on s.id = l.subject_id
      left join topics t on t.id = l.topic_id
      where l.student_id = p_student and l.logged_on >= p_since
    ), '[]'::jsonb),

    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', ss.id,
          'type', ss.type,
          'started_at', ss.started_at,
          'duration_sec', ss.duration_sec,
          'subjects', case when s.id is null then null
                           else jsonb_build_object('code', s.code) end
        ) order by ss.started_at desc)
      from study_sessions ss
      left join subjects s on s.id = ss.subject_id
      where ss.student_id = p_student and ss.started_at >= p_since_ts
    ), '[]'::jsonb),

    'goals', (select to_jsonb(g) from goals g where g.student_id = p_student),

    'topic_progress', coalesce((
      select jsonb_agg(jsonb_build_object(
          'topic_id', tp.topic_id, 'status', tp.status))
      from topic_progress tp
      where tp.student_id = p_student
    ), '[]'::jsonb),

    'exams', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', e.id,
          'exam_type', e.exam_type,
          'field', e.field,
          'name', e.name,
          'publisher', e.publisher,
          'taken_on', e.taken_on,
          'created_at', e.created_at,
          'exam_subject_results', coalesce((
            select jsonb_agg(jsonb_build_object(
                'correct', r.correct,
                'wrong', r.wrong,
                'blank', r.blank,
                'subjects', jsonb_build_object('code', s.code)))
            from exam_subject_results r
            join subjects s on s.id = r.subject_id
            where r.exam_id = e.id
          ), '[]'::jsonb)
        ) order by e.taken_on desc, e.created_at desc)
      from exams e
      where e.student_id = p_student
    ), '[]'::jsonb),

    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'title', a.title,
          'note', a.note,
          'due_on', a.due_on,
          'created_at', a.created_at,
          'coach', case when c.id is null then null
                        else jsonb_build_object('full_name', c.full_name) end,
          'assignment_items', coalesce((
            select jsonb_agg(jsonb_build_object(
                'id', i.id,
                'question_count', i.question_count,
                'note', i.note,
                'sort', i.sort,
                'done', i.done,
                'subjects', jsonb_build_object('code', s.code),
                'topics', case when t.id is null then null
                               else jsonb_build_object('id', t.id, 'name', t.name) end))
            from assignment_items i
            join subjects s on s.id = i.subject_id
            left join topics t on t.id = i.topic_id
            where i.assignment_id = a.id
          ), '[]'::jsonb)
        ) order by a.created_at desc)
      from assignments a
      left join profiles c on c.id = a.coach_id
      where a.student_id = p_student
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.student_home(uuid, date, timestamptz) from public, anon;
grant execute on function public.student_home(uuid, date, timestamptz) to authenticated;

-- 3. Toplu push'ları zamana yay -------------------------------------------------
-- Önceden her bildirim satırı anında bir Edge Function çağrısı yapıyordu.
-- Duyuru, deneme paketi ya da Günün Sorusu binlerce satırı aynı anda
-- eklediğinde binlerce çağrı ve ardından binlerce eş zamanlı uygulama açılışı
-- oluyordu. Şimdi:
--   * Son 10 saniyede push_burst_limit'ten az bildirim varsa: eskisi gibi anında.
--   * Fazlaysa: push_queue'ya saniyede push_rate_per_sec olacak şekilde sıra
--     zamanı verilir; pg_cron 15 saniyede bir vadesi gelenleri 100'lük
--     paketler hâlinde send-push'a yollar (tek çağrı, 100 bildirim).

create index if not exists notifications_created_at_idx
  on public.notifications (created_at);

create table public.push_queue (
  notification_id uuid primary key
    references public.notifications (id) on delete cascade,
  due_at timestamptz not null
);
create index push_queue_due_at_idx on public.push_queue (due_at);
alter table public.push_queue enable row level security;
-- Politika yok: yalnızca aşağıdaki SECURITY DEFINER fonksiyonlar dokunur.
revoke all on public.push_queue from anon, authenticated;

-- send-push'u çağırır; Vault ayarı yoksa (yerel test) hiçbir şey yapmaz.
create or replace function public.post_push(p_body jsonb)
returns void
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
    return;
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret),
    body := p_body,
    timeout_milliseconds := 30000);
exception when others then
  raise warning 'post_push: %', sqlerrm;
end;
$$;
revoke execute on function public.post_push(jsonb) from public, anon, authenticated;

create or replace function public.push_on_notification()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  -- Bu kadarına kadar anında gider (tekli bildirimler hep anında).
  push_burst_limit  constant int := 30;
  -- Kuyruktakiler saniyede bu kadar: 5.000 bildirim ≈ 2 dakika.
  push_rate_per_sec constant int := 40;
  v_recent int;
  v_last   timestamptz;
begin
  -- Sınırdan fazlasını saymaya gerek yok (binlerce satırlık eklemede ucuz kalsın).
  select count(*) into v_recent
  from (
    select 1 from public.notifications
    where created_at > now() - interval '10 seconds'
    limit push_burst_limit + 1
  ) recent;

  if v_recent <= push_burst_limit then
    perform public.post_push(jsonb_build_object('notification_id', new.id));
    return new;
  end if;

  select max(due_at) into v_last from public.push_queue;
  insert into public.push_queue (notification_id, due_at)
  values (
    new.id,
    greatest(coalesce(v_last, now()), now())
      + make_interval(secs => 1.0 / push_rate_per_sec)
  );
  return new;
exception when others then
  -- Bildirim gönderilemese de uygulama içi bildirim kaydı kalır.
  raise warning 'push_on_notification: %', sqlerrm;
  return new;
end;
$$;
revoke execute on function public.push_on_notification() from public, anon, authenticated;

-- Vadesi gelenleri 100'lük paketlerle gönderir; pg_cron çağırır.
create or replace function public.drain_push_queue(p_limit int default 2000)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_ids   uuid[];
  v_n     int;
  i       int := 1;
begin
  with due as (
    select notification_id
    from public.push_queue
    where due_at <= now()
    order by due_at
    limit p_limit
    for update skip locked
  ), gone as (
    delete from public.push_queue q
    using due
    where q.notification_id = due.notification_id
    returning q.notification_id
  )
  select coalesce(array_agg(notification_id), '{}') into v_ids from gone;

  v_n := coalesce(array_length(v_ids, 1), 0);
  while i <= v_n loop
    perform public.post_push(
      jsonb_build_object('notification_ids', to_jsonb(v_ids[i : i + 99])));
    i := i + 100;
  end loop;
  return v_n;
end;
$$;
revoke execute on function public.drain_push_queue(int) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('drain-push-queue', '15 seconds',
      'select public.drain_push_queue()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); kuyruk zamanlanmadı';
  end if;
end;
$$;

-- 4. Koç / müdür panelleri ------------------------------------------------------
-- student_summaries() ve exam_trends() platformdaki TÜM öğrencileri (ve tüm
-- denemeleri) gezip her satırda can_manage_student() çağırıyordu: maliyet,
-- kurumun değil platformun büyüklüğüyle artıyordu. Şimdi önce yönettiğim
-- öğrencilerin listesi çıkarılıyor (koç: coach_students, müdür: kurum),
-- sonra yalnızca onların verisine bakılıyor. Sonuç aynı.

-- can_manage_student(x) doğru ⇔ x bu kümede.
create or replace function public.my_managed_students()
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select cs.student_id
  from public.coach_students cs
  where cs.coach_id = auth.uid()
  union
  select t.id
  from public.profiles me
  join public.profiles t on t.org_id = me.org_id
  where me.id = auth.uid() and me.role = 'admin'
$$;
revoke execute on function public.my_managed_students() from public, anon;
grant execute on function public.my_managed_students() to authenticated;

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
  with mine as (
    select m.id from public.my_managed_students() m(id)
    where public.my_tenant_active()
  ), recent as (
    select e.student_id, e.taken_on,
           (select coalesce(sum(r.net), 0) from public.exam_subject_results r
            where r.exam_id = e.id) as net,
           row_number() over (partition by e.student_id
                              order by e.taken_on desc, e.created_at desc) as rn
    from mine
    join public.exams e on e.student_id = mine.id
    join public.profiles p on p.id = e.student_id
    where p.role = 'student'
      and e.exam_type::text = p_exam_type
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
