-- =====================================================================
-- Kurum müdürü kokpiti (NOTLAR §59)
-- ---------------------------------------------------------------------
--  * profiles.last_seen_at: uygulamanın son açılışı. İstemci açılışta ve
--    öne gelişte touch_last_seen() çağırır; saatte en çok bir kez yazılır.
--  * org_exam_plans: kurumun planladığı denemeler (ad, tür, tarih). Yalnızca
--    müdür yazar (add_exam_plan / delete_exam_plan); müdür ve koçlar okur.
--  * coach_phones: müdürün girdiği koç telefonu ("koçu ara" düğmesi).
--    Müdür ve koçun kendisi okur; yazma set_coach_phone ile.
--  * notify_coach_about_student: müdürden koça "şu öğrenciyle ilgilen"
--    bildirimi (kind 'coach_alert', push da gider). Aynı öğrenci için
--    6 saatte bir.
--  * admin_cockpit(): tek çağrıda özet şeridi (bu hafta / geçen hafta),
--    dikkat listeleri (7+ gün girmeyen, son iki denemede 3+ net düşen,
--    taksiti geciken) ve koç performansı. Yalnızca müdür.
--
-- Geri almak için: supabase/rollbacks/20261106160000_admin_cockpit.down.sql
-- =====================================================================

alter table public.profiles add column if not exists last_seen_at timestamptz;

create or replace function public.touch_last_seen()
returns void
language sql security definer set search_path = ''
as $$
  update public.profiles
     set last_seen_at = now()
   where id = auth.uid()
     and (last_seen_at is null or last_seen_at < now() - interval '1 hour')
$$;
revoke all on function public.touch_last_seen() from public, anon;
grant execute on function public.touch_last_seen() to authenticated;

-- ---------------------------------------------------------------------
-- Deneme takvimi
-- ---------------------------------------------------------------------
create table public.org_exam_plans (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  name       text not null check (length(trim(name)) between 2 and 80),
  exam_type  public.exam_type not null default 'TYT',
  planned_on date not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.org_exam_plans (org_id, planned_on);
create index on public.org_exam_plans (tenant_id);

alter table public.org_exam_plans enable row level security;
create policy "org staff reads exam plans" on public.org_exam_plans
  for select to authenticated
  using (org_id = (select p.org_id from public.profiles p
                   where p.id = (select auth.uid()) and p.role in ('admin', 'coach')));
create policy "tenant isolation" on public.org_exam_plans as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()));
revoke all on public.org_exam_plans from anon;
revoke insert, update, delete, truncate, trigger, references on public.org_exam_plans from authenticated;

create or replace function public.add_exam_plan(
  p_name text, p_type public.exam_type, p_on date)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  v_id  uuid;
begin
  if v_org is null then
    raise exception 'COCKPIT_NOT_ADMIN';
  end if;
  if p_on is null or p_on < current_date - 1 or p_on > current_date + 400 then
    raise exception 'EXAM_PLAN_BAD_DATE';
  end if;
  insert into public.org_exam_plans (org_id, tenant_id, name, exam_type, planned_on, created_by)
  values (v_org, (select tenant_id from public.organizations where id = v_org),
          trim(p_name), coalesce(p_type, 'TYT'), p_on, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.add_exam_plan(text, public.exam_type, date) from public, anon;
grant execute on function public.add_exam_plan(text, public.exam_type, date) to authenticated;

create or replace function public.delete_exam_plan(p_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  delete from public.org_exam_plans
   where id = p_id
     and org_id = (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  if not found then
    raise exception 'EXAM_PLAN_NOT_FOUND';
  end if;
end;
$$;
revoke all on function public.delete_exam_plan(uuid) from public, anon;
grant execute on function public.delete_exam_plan(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Koç telefonu
-- ---------------------------------------------------------------------
create table public.coach_phones (
  coach_id   uuid primary key references public.profiles (id) on delete cascade,
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  phone      text not null check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  updated_at timestamptz not null default now()
);
create index on public.coach_phones (org_id);
create index on public.coach_phones (tenant_id);

alter table public.coach_phones enable row level security;
create policy "admin or self reads coach phone" on public.coach_phones
  for select to authenticated
  using (coach_id = (select auth.uid()) or (select public.is_org_admin(org_id)));
create policy "tenant isolation" on public.coach_phones as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()));
revoke all on public.coach_phones from anon;
revoke insert, update, delete, truncate, trigger, references on public.coach_phones from authenticated;

-- p_phone null ya da boş: numarayı siler. Biçim: +905321112233.
create or replace function public.set_coach_phone(p_coach uuid, p_phone text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
begin
  if v_org is null then
    raise exception 'COCKPIT_NOT_ADMIN';
  end if;
  if not exists (select 1 from public.profiles
                 where id = p_coach and role = 'coach' and org_id = v_org) then
    raise exception 'COACH_NOT_FOUND';
  end if;
  if nullif(trim(coalesce(p_phone, '')), '') is null then
    delete from public.coach_phones where coach_id = p_coach;
    return;
  end if;
  insert into public.coach_phones (coach_id, org_id, tenant_id, phone)
  values (p_coach, v_org, (select tenant_id from public.organizations where id = v_org), trim(p_phone))
  on conflict (coach_id) do update set phone = excluded.phone, updated_at = now();
end;
$$;
revoke all on function public.set_coach_phone(uuid, text) from public, anon;
grant execute on function public.set_coach_phone(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- Müdürden koça bildirim
-- ---------------------------------------------------------------------
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest', 'installment_due',
                  'timetable', 'book_request', 'coach_alert'));

create or replace function public.notify_coach_about_student(p_student uuid, p_reason text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin public.profiles%rowtype;
  v_name  text;
  v_coach uuid;
begin
  select * into v_admin from public.profiles where id = auth.uid() and role = 'admin';
  if v_admin.id is null then
    raise exception 'COCKPIT_NOT_ADMIN';
  end if;
  select p.full_name, cs.coach_id into v_name, v_coach
    from public.profiles p
    left join public.coach_students cs on cs.student_id = p.id
   where p.id = p_student and p.role = 'student' and p.org_id = v_admin.org_id;
  if v_name is null then
    raise exception 'STUDENT_NOT_FOUND';
  end if;
  if v_coach is null then
    raise exception 'STUDENT_HAS_NO_COACH';
  end if;
  if exists (select 1 from public.notifications
             where user_id = v_coach and kind = 'coach_alert' and ref_id = p_student
               and created_at > now() - interval '6 hours') then
    raise exception 'COACH_ALERT_RECENT';
  end if;
  insert into public.notifications (user_id, kind, ref_id, data)
  values (v_coach, 'coach_alert', p_student, jsonb_build_object(
    'student', v_name,
    'from', v_admin.full_name,
    'reason', left(coalesce(p_reason, ''), 200),
    'route', '/coach/students/' || p_student));
end;
$$;
revoke all on function public.notify_coach_about_student(uuid, text) from public, anon;
grant execute on function public.notify_coach_about_student(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- Kokpit verisi
-- ---------------------------------------------------------------------
-- "Bu hafta" son 7 gün, "geçen hafta" ondan önceki 7 gündür (öğrenci
-- özetleriyle aynı). Koç görüşmeleri pazartesi başlayan bu haftadır.
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
           -- Son görülme henüz yazılmamışsa son çalışma kaydı sayılır.
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
