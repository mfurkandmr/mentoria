-- =====================================================================
-- Soru çözümü, birebir ders ve etüt oturumları + öğrenci talepleri
-- ---------------------------------------------------------------------
-- Plan: docs/OGRETMEN_WHATSAPP_PLANI.md (B), NOTLAR §87. Kullanıcı kararı:
-- talebi yalnızca öğretmen onaylar / reddeder; koç (ve müdür) görür.
--
--  * tutoring_sessions: müdürün haftalık oturumları (gün + saat aralığı,
--    öğretmen, tür, kontenjan, branş, derslik). Öğretmenin aynı gün çakışan
--    başka oturumu ya da yayındaki programda o saatte dersi varsa reddedilir.
--    Yazma/okuma doğrudan yalnızca müdür; diğerleri RPC ile.
--  * tutoring_requests: öğrencinin belirli bir güne talebi (pending →
--    approved / rejected; öğrenci cancelled). Doğrudan erişim yok, hepsi RPC.
--    Kurallar: en çok 14 gün sonrası, başlamış oturuma talep yok, aynı
--    oturuma aynı gün tek etkin talep, günde en çok 3 etkin talep, onaylı
--    sayısı kontenjana ulaştıysa TUTOR_SESSION_FULL.
--  * Bildirim 'tutoring_request': yeni talep öğretmene (hesabı varsa),
--    karar öğrenciye.
--
-- Geri almak için: supabase/rollbacks/20261111120000_tutoring_sessions.down.sql
-- =====================================================================

create table public.tutoring_sessions (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  teacher_id uuid not null references public.teachers (id) on delete cascade,
  kind       text not null default 'question_solving'
             check (kind in ('question_solving', 'private_lesson', 'etut')),
  day        smallint not null check (day between 1 and 7),
  start_time time not null,
  end_time   time not null,
  capacity   smallint not null default 1 check (capacity between 1 and 60),
  branch     text check (length(branch) between 1 and 40),
  room_id    uuid references public.rooms (id) on delete set null,
  note       text check (length(note) <= 200),
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);
create index on public.tutoring_sessions (org_id, day);
create index on public.tutoring_sessions (teacher_id);
create index on public.tutoring_sessions (room_id);
create index on public.tutoring_sessions (tenant_id);

create table public.tutoring_requests (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations (id) on delete cascade,
  tenant_id     uuid not null references public.tenants (id),
  session_id    uuid not null references public.tutoring_sessions (id) on delete cascade,
  student_id    uuid not null references public.profiles (id) on delete cascade,
  on_date       date not null,
  topic         text check (length(topic) <= 200),
  status        text not null default 'pending'
                check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  reject_reason text check (length(reject_reason) <= 200),
  decided_by    uuid references public.profiles (id) on delete set null,
  decided_at    timestamptz,
  created_at    timestamptz not null default now()
);
create unique index tutoring_requests_one_active
  on public.tutoring_requests (session_id, student_id, on_date)
  where status in ('pending', 'approved');
create index on public.tutoring_requests (session_id, on_date);
create index on public.tutoring_requests (student_id, on_date);
create index on public.tutoring_requests (org_id);
create index on public.tutoring_requests (tenant_id);
create index on public.tutoring_requests (decided_by);

-- Türkiye saatiyle bugün / şimdi.
create or replace function public.tr_now()
returns timestamp
language sql stable set search_path = ''
as $$ select now() at time zone 'Europe/Istanbul' $$;
revoke all on function public.tr_now() from public, anon;

-- ---------------------------------------------------------------------
-- Oturum koruması: kurum sunucuda, bağlantılar aynı kurumdan, çakışma yok.
-- ---------------------------------------------------------------------
create or replace function public.guard_tutoring_session()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.org_id := old.org_id;
    new.created_at := old.created_at;
  else
    new.org_id := (select org_id from public.profiles
                   where id = auth.uid() and role = 'admin');
    new.created_at := now();
  end if;
  if new.org_id is null or (auth.uid() is not null and not public.is_org_admin(new.org_id)) then
    raise exception 'TUTOR_NOT_ADMIN';
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);
  if not exists (select 1 from public.teachers
                 where id = new.teacher_id and org_id = new.org_id) then
    raise exception 'TUTOR_BAD_REF';
  end if;
  if new.room_id is not null
     and not exists (select 1 from public.rooms
                     where id = new.room_id and org_id = new.org_id) then
    raise exception 'TUTOR_BAD_REF';
  end if;
  if new.kind = 'private_lesson' then
    new.capacity := 1;
  end if;
  new.branch := nullif(trim(new.branch), '');
  new.note := nullif(trim(new.note), '');

  if new.active then
    if exists (select 1 from public.tutoring_sessions s
               where s.teacher_id = new.teacher_id and s.active
                 and s.id <> new.id and s.day = new.day
                 and s.start_time < new.end_time and new.start_time < s.end_time) then
      raise exception 'TUTOR_SESSION_OVERLAP';
    end if;
    if exists (select 1 from public.schedule_entries e
               join public.schedules sc on sc.id = e.schedule_id and sc.status = 'published'
               join public.time_slots ts on ts.id = e.time_slot_id
               where e.teacher_id = new.teacher_id and ts.day = new.day
                 and ts.start_time < new.end_time and new.start_time < ts.end_time) then
      raise exception 'TUTOR_TEACHER_BUSY';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_tutoring_session() from public, anon, authenticated;

create trigger guard_tutoring_session before insert or update on public.tutoring_sessions
  for each row execute function public.guard_tutoring_session();

alter table public.tutoring_sessions enable row level security;
create policy "org admin manages" on public.tutoring_sessions for all to authenticated
  using ((select public.is_org_admin(org_id)))
  with check ((select public.is_org_admin(org_id)));
create policy "tenant isolation" on public.tutoring_sessions as restrictive for all to public
  using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()));
revoke all on public.tutoring_sessions from anon;
revoke truncate, trigger, references on public.tutoring_sessions from authenticated;

-- Talepler: yalnızca RPC.
alter table public.tutoring_requests enable row level security;
create policy "tenant isolation" on public.tutoring_requests as restrictive for all to public
  using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()));
revoke all on public.tutoring_requests from anon, authenticated;

-- Bildirim türü.
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest', 'installment_due',
                  'timetable', 'book_request', 'coach_alert', 'tutoring_request'));

-- ---------------------------------------------------------------------
-- Öğrenci: önümüzdeki günlerin açık oturumları
-- ---------------------------------------------------------------------
create or replace function public.open_tutoring_sessions(p_from date, p_days integer default 7)
returns table (
  session_id   uuid,
  on_date      date,
  kind         text,
  start_time   time,
  end_time     time,
  branch       text,
  teacher_name text,
  room_name    text,
  capacity     smallint,
  taken        integer,
  my_request   uuid,
  my_status    text
)
language sql stable security definer set search_path = ''
as $$
  with me as (
    select p.id, p.org_id from public.profiles p
    where p.id = auth.uid() and p.role = 'student'
  ),
  days as (
    select d::date d
    from generate_series(greatest(p_from, public.tr_now()::date),
                         least(p_from + least(greatest(p_days, 1), 14) - 1,
                               public.tr_now()::date + 14),
                         interval '1 day') d
  )
  select s.id, days.d, s.kind, s.start_time, s.end_time,
         coalesce(s.branch, t.branches[1]), t.full_name, r.name, s.capacity,
         (select count(*)::int from public.tutoring_requests q
          where q.session_id = s.id and q.on_date = days.d and q.status = 'approved'),
         mine.id, mine.status
  from me
  join public.tutoring_sessions s on s.org_id = me.org_id and s.active
  join days on extract(isodow from days.d) = s.day
  join public.teachers t on t.id = s.teacher_id
  left join public.rooms r on r.id = s.room_id
  left join lateral (
    select q.id, q.status from public.tutoring_requests q
    where q.session_id = s.id and q.on_date = days.d and q.student_id = me.id
    order by (q.status in ('pending', 'approved')) desc, q.created_at desc
    limit 1
  ) mine on true
  where (select public.my_tenant_active())
    and (days.d > public.tr_now()::date or s.start_time > public.tr_now()::time)
  order by days.d, s.start_time, t.full_name
$$;
revoke all on function public.open_tutoring_sessions(date, integer) from public, anon;
grant execute on function public.open_tutoring_sessions(date, integer) to authenticated;

create or replace function public.request_tutoring_session(
  p_session uuid, p_date date, p_topic text default null)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_me    public.profiles%rowtype;
  v_s     public.tutoring_sessions%rowtype;
  v_t     public.teachers%rowtype;
  v_now   timestamp := public.tr_now();
  v_id    uuid;
begin
  select * into v_me from public.profiles where id = auth.uid() and role = 'student';
  if v_me.id is null or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  select * into v_s from public.tutoring_sessions where id = p_session for update;
  if v_s.id is null or not v_s.active or v_s.org_id is distinct from v_me.org_id then
    raise exception 'TUTOR_SESSION_NOT_FOUND';
  end if;
  if p_date is null or extract(isodow from p_date) <> v_s.day
     or p_date < v_now::date or p_date > v_now::date + 14
     or (p_date = v_now::date and v_s.start_time <= v_now::time) then
    raise exception 'TUTOR_BAD_DATE';
  end if;
  if exists (select 1 from public.tutoring_requests
             where session_id = p_session and student_id = v_me.id and on_date = p_date
               and status in ('pending', 'approved')) then
    raise exception 'TUTOR_ALREADY_REQUESTED';
  end if;
  if (select count(*) from public.tutoring_requests
      where student_id = v_me.id and on_date = p_date
        and status in ('pending', 'approved')) >= 3 then
    raise exception 'TUTOR_DAILY_LIMIT';
  end if;
  if (select count(*) from public.tutoring_requests
      where session_id = p_session and on_date = p_date and status = 'approved')
     >= v_s.capacity then
    raise exception 'TUTOR_SESSION_FULL';
  end if;

  insert into public.tutoring_requests
    (org_id, tenant_id, session_id, student_id, on_date, topic)
  values (v_s.org_id, v_s.tenant_id, p_session, v_me.id, p_date,
          nullif(left(trim(coalesce(p_topic, '')), 200), ''))
  returning id into v_id;

  select * into v_t from public.teachers where id = v_s.teacher_id;
  if v_t.profile_id is not null then
    insert into public.notifications (user_id, kind, ref_id, data)
    values (v_t.profile_id, 'tutoring_request', v_id, jsonb_build_object(
      'event', 'new',
      'student', v_me.full_name,
      'session_kind', v_s.kind,
      'branch', coalesce(v_s.branch, v_t.branches[1]),
      'date', p_date,
      'time', to_char(v_s.start_time, 'HH24:MI'),
      'route', '/teacher'));
  end if;
  return v_id;
end;
$$;
revoke all on function public.request_tutoring_session(uuid, date, text) from public, anon;
grant execute on function public.request_tutoring_session(uuid, date, text) to authenticated;

create or replace function public.cancel_tutoring_request(p_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.tutoring_requests
  set status = 'cancelled'
  where id = p_id and student_id = auth.uid()
    and status in ('pending', 'approved')
    and on_date >= public.tr_now()::date;
  if not found then
    raise exception 'NOT_ALLOWED';
  end if;
end;
$$;
revoke all on function public.cancel_tutoring_request(uuid) from public, anon;
grant execute on function public.cancel_tutoring_request(uuid) to authenticated;

-- Öğrencinin kendi talepleri (bugünden itibaren).
create or replace function public.my_tutoring_requests()
returns table (
  id           uuid,
  session_id   uuid,
  on_date      date,
  kind         text,
  start_time   time,
  end_time     time,
  branch       text,
  teacher_name text,
  topic        text,
  status       text,
  reject_reason text
)
language sql stable security definer set search_path = ''
as $$
  select q.id, s.id, q.on_date, s.kind, s.start_time, s.end_time,
         coalesce(s.branch, t.branches[1]), t.full_name, q.topic, q.status, q.reject_reason
  from public.tutoring_requests q
  join public.tutoring_sessions s on s.id = q.session_id
  join public.teachers t on t.id = s.teacher_id
  where q.student_id = auth.uid()
    and q.on_date >= public.tr_now()::date
    and q.status <> 'cancelled'
  order by q.on_date, s.start_time
$$;
revoke all on function public.my_tutoring_requests() from public, anon;
grant execute on function public.my_tutoring_requests() to authenticated;

-- ---------------------------------------------------------------------
-- Öğretmen: oturumlarım, taleplerim, karar
-- ---------------------------------------------------------------------
create or replace function public.my_tutoring_sessions()
returns table (
  id         uuid,
  kind       text,
  day        smallint,
  start_time time,
  end_time   time,
  capacity   smallint,
  branch     text,
  room_name  text
)
language sql stable security definer set search_path = ''
as $$
  select s.id, s.kind, s.day, s.start_time, s.end_time, s.capacity,
         coalesce(s.branch, t.branches[1]), r.name
  from public.tutoring_sessions s
  join public.teachers t on t.id = s.teacher_id and t.profile_id = auth.uid()
  left join public.rooms r on r.id = s.room_id
  where s.active
  order by s.day, s.start_time
$$;
revoke all on function public.my_tutoring_sessions() from public, anon;
grant execute on function public.my_tutoring_sessions() to authenticated;

create or replace function public.teacher_tutoring_requests(p_from date, p_days integer default 14)
returns table (
  id           uuid,
  session_id   uuid,
  on_date      date,
  kind         text,
  start_time   time,
  end_time     time,
  branch       text,
  capacity     smallint,
  student_name text,
  class_name   text,
  topic        text,
  status       text,
  created_at   timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select q.id, s.id, q.on_date, s.kind, s.start_time, s.end_time,
         coalesce(s.branch, t.branches[1]), s.capacity, p.full_name,
         (select c.name from public.classroom_students cs
          join public.classrooms c on c.id = cs.classroom_id
          where cs.student_id = q.student_id limit 1),
         q.topic, q.status, q.created_at
  from public.tutoring_requests q
  join public.tutoring_sessions s on s.id = q.session_id
  join public.teachers t on t.id = s.teacher_id and t.profile_id = auth.uid()
  join public.profiles p on p.id = q.student_id
  where q.on_date between p_from and p_from + least(greatest(p_days, 1), 31) - 1
    and q.status <> 'cancelled'
  order by q.on_date, s.start_time, q.created_at
$$;
revoke all on function public.teacher_tutoring_requests(date, integer) from public, anon;
grant execute on function public.teacher_tutoring_requests(date, integer) to authenticated;

create or replace function public.decide_tutoring_request(
  p_id uuid, p_approve boolean, p_reason text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_q public.tutoring_requests%rowtype;
  v_s public.tutoring_sessions%rowtype;
  v_t public.teachers%rowtype;
begin
  select * into v_q from public.tutoring_requests where id = p_id for update;
  select * into v_s from public.tutoring_sessions where id = v_q.session_id for update;
  select * into v_t from public.teachers where id = v_s.teacher_id;
  if v_q.id is null or v_t.profile_id is distinct from auth.uid() then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_q.status <> 'pending' then
    raise exception 'TUTOR_ALREADY_DECIDED';
  end if;
  if p_approve and (select count(*) from public.tutoring_requests
                    where session_id = v_s.id and on_date = v_q.on_date
                      and status = 'approved') >= v_s.capacity then
    raise exception 'TUTOR_SESSION_FULL';
  end if;

  update public.tutoring_requests
  set status = case when p_approve then 'approved' else 'rejected' end,
      reject_reason = case when p_approve then null
                           else nullif(left(trim(coalesce(p_reason, '')), 200), '') end,
      decided_by = auth.uid(),
      decided_at = now()
  where id = p_id;

  insert into public.notifications (user_id, kind, ref_id, data)
  values (v_q.student_id, 'tutoring_request', p_id, jsonb_build_object(
    'event', case when p_approve then 'approved' else 'rejected' end,
    'teacher', v_t.full_name,
    'session_kind', v_s.kind,
    'branch', coalesce(v_s.branch, v_t.branches[1]),
    'date', v_q.on_date,
    'time', to_char(v_s.start_time, 'HH24:MI'),
    'reason', case when p_approve then null
                   else nullif(left(trim(coalesce(p_reason, '')), 200), '') end,
    'route', '/student/study'));
end;
$$;
revoke all on function public.decide_tutoring_request(uuid, boolean, text) from public, anon;
grant execute on function public.decide_tutoring_request(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------
-- Koç (kendi öğrencileri) ve müdür (kurum): salt okunur
-- ---------------------------------------------------------------------
create or replace function public.managed_tutoring_requests(p_from date, p_days integer default 14)
returns table (
  id           uuid,
  student_id   uuid,
  student_name text,
  on_date      date,
  kind         text,
  start_time   time,
  end_time     time,
  branch       text,
  teacher_name text,
  topic        text,
  status       text
)
language sql stable security definer set search_path = ''
as $$
  select q.id, q.student_id, p.full_name, q.on_date, s.kind, s.start_time, s.end_time,
         coalesce(s.branch, t.branches[1]), t.full_name, q.topic, q.status
  from public.tutoring_requests q
  join public.tutoring_sessions s on s.id = q.session_id
  join public.teachers t on t.id = s.teacher_id
  join public.profiles p on p.id = q.student_id
  where q.student_id in (select public.my_managed_students())
    and q.on_date between p_from and p_from + least(greatest(p_days, 1), 31) - 1
    and q.status <> 'cancelled'
  order by q.on_date, s.start_time, p.full_name
$$;
revoke all on function public.managed_tutoring_requests(date, integer) from public, anon;
grant execute on function public.managed_tutoring_requests(date, integer) to authenticated;

-- ---------------------------------------------------------------------
-- merge_teachers (20261111110000 sürümü) + soru çözümü oturumları
-- ---------------------------------------------------------------------
create or replace function public.merge_teachers(p_keep uuid, p_from uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_keep public.teachers%rowtype;
  v_from public.teachers%rowtype;
begin
  select * into v_keep from public.teachers where id = p_keep for update;
  select * into v_from from public.teachers where id = p_from for update;
  if v_keep.id is null or v_from.id is null or p_keep = p_from
     or v_keep.org_id <> v_from.org_id or not public.is_org_admin(v_keep.org_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_keep.profile_id is not null or v_from.profile_id is null then
    raise exception 'TEACHER_MERGE_BAD_PAIR';
  end if;

  begin
    update public.schedule_entries set teacher_id = p_keep where teacher_id = p_from;
  exception when unique_violation then
    raise exception 'TEACHER_MERGE_CONFLICT';
  end;
  update public.class_lessons set teacher_id = p_keep where teacher_id = p_from;
  -- Soru çözümü oturumları da taşınır (yoksa öğretmen silinince giderdi).
  begin
    update public.tutoring_sessions set teacher_id = p_keep where teacher_id = p_from;
  exception when raise_exception then
    if sqlerrm in ('TUTOR_SESSION_OVERLAP', 'TUTOR_TEACHER_BUSY') then
      raise exception 'TEACHER_MERGE_CONFLICT';
    end if;
    raise;
  end;
  -- Müsaitlik: elle girilen varsa o kalır.
  if exists (select 1 from public.teacher_availability where teacher_id = p_keep) then
    delete from public.teacher_availability where teacher_id = p_from;
  else
    update public.teacher_availability set teacher_id = p_keep where teacher_id = p_from;
  end if;
  -- Ücret: elle girilen varsa o kalır; yoksa hesabınki kopyalanır.
  if not exists (select 1 from public.teacher_pay_rates where teacher_id = p_keep) then
    insert into public.teacher_pay_rates (teacher_id, pay_type, amount, note)
    select p_keep, pay_type, amount, note
    from public.teacher_pay_rates where teacher_id = p_from;
  end if;
  update public.finance_expenses set teacher_id = p_keep where teacher_id = p_from;
  if not exists (select 1 from public.staff_members where teacher_id = p_keep) then
    update public.staff_members set teacher_id = p_keep where teacher_id = p_from;
  end if;

  delete from public.teachers where id = p_from;
  update public.teachers
  set profile_id = v_from.profile_id,
      -- Elle girilen branşlar önce; hesabın varsayılan 'Genel'i eklenmez.
      branches = public.clean_teacher_branches(
        v_keep.branches || array_remove(v_from.branches, 'Genel'))
  where id = p_keep;
end;
$$;
revoke all on function public.merge_teachers(uuid, uuid) from public, anon;
grant execute on function public.merge_teachers(uuid, uuid) to authenticated;
