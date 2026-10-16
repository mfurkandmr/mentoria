-- =====================================================================
-- Koç–öğrenci görüşmeleri
--
-- Koç her öğrencisi için görüşme planlar: tek seferlik ya da haftalık rutin
-- ("Ahmet ile her salı 11:00"). Öğrenci, velisi ve kurum müdürü görür.
--  * meeting_schedules: plan. Haftalık rutinde ilk tarih + 7 günün katları;
--    until_date verilirse rutin o tarihte biter (geçmiş kayıtlar kalır).
--  * meeting_occurrences: tek bir günün görüşmesi. Koç "yapıldı / yapılmadı /
--    iptal" işaretler (set_meeting_status); hatırlatma gönderildiyse
--    reminded_at dolar. Doğrudan yazma yok.
--  * Saatler Türkiye saatidir (Europe/Istanbul).
--  * send_meeting_reminders(): görüşmesine 24 saatten az kalan öğrenciye
--    'meeting' bildirimi düşer (bildirim → mevcut push tetikleyicisi).
--    pg_cron varsa 10 dakikada bir çalışır; aynı görüşme için tek bildirim.
--  * tenant_id istemciden alınmaz (set_tenant_id), RESTRICTIVE izolasyon var.
--
-- Geri almak için: supabase/rollbacks/20261018100000_meetings.down.sql
-- =====================================================================

create table public.meeting_schedules (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.tenants (id),
  coach_id      uuid not null references public.profiles (id) on delete cascade,
  student_id    uuid not null references public.profiles (id) on delete cascade,
  first_date    date not null,
  start_time    time not null,
  duration_min  smallint not null default 30 check (duration_min between 10 and 180),
  repeat_weekly boolean not null default true,
  until_date    date,
  note          text check (char_length(note) <= 200),
  created_at    timestamptz not null default now()
);
create index on public.meeting_schedules (student_id);
create index on public.meeting_schedules (coach_id);
create index on public.meeting_schedules (tenant_id);

create table public.meeting_occurrences (
  schedule_id uuid not null references public.meeting_schedules (id) on delete cascade,
  occurs_on   date not null,
  student_id  uuid not null references public.profiles (id) on delete cascade,
  tenant_id   uuid not null references public.tenants (id),
  status      text check (status in ('held', 'missed', 'cancelled')),
  marked_by   uuid references public.profiles (id) on delete set null,
  marked_at   timestamptz,
  reminded_at timestamptz,
  primary key (schedule_id, occurs_on)
);
create index on public.meeting_occurrences (student_id, occurs_on);
create index on public.meeting_occurrences (tenant_id);

create trigger set_tenant_id before insert or update on public.meeting_schedules
  for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.meeting_occurrences
  for each row execute function public.set_tenant_id();

alter table public.meeting_schedules   enable row level security;
alter table public.meeting_occurrences enable row level security;

-- Öğrenci, velisi, koçu ve kurum müdürü görür.
create policy "read meeting schedules" on public.meeting_schedules
  for select to authenticated
  using ((select public.can_view_student(student_id)));
-- Yalnızca öğrencinin koçu kendi adına planlar ve değiştirir.
create policy "coach creates meetings" on public.meeting_schedules
  for insert to authenticated
  with check (coach_id = (select auth.uid())
              and (select public.is_coach_of(student_id)));
create policy "coach updates meetings" on public.meeting_schedules
  for update to authenticated
  using (coach_id = (select auth.uid()))
  with check (coach_id = (select auth.uid())
              and (select public.is_coach_of(student_id)));
create policy "coach deletes meetings" on public.meeting_schedules
  for delete to authenticated
  using (coach_id = (select auth.uid()));
create policy "tenant isolation" on public.meeting_schedules as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));

create policy "read meeting occurrences" on public.meeting_occurrences
  for select to authenticated
  using ((select public.can_view_student(student_id)));
create policy "tenant isolation" on public.meeting_occurrences as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));

revoke all on public.meeting_schedules from anon;
revoke all on public.meeting_occurrences from anon;
-- Görüşme durumu yalnızca set_meeting_status ile yazılır.
revoke insert, update, delete on public.meeting_occurrences from authenticated;

-- Bu planın o gün bir görüşmesi var mı?
create or replace function public.meeting_occurs_on(
  p_first date, p_weekly boolean, p_until date, p_day date)
returns boolean
language sql immutable set search_path = ''
as $$
  select p_day >= p_first
     and (p_until is null or p_day <= p_until)
     and case when p_weekly then (p_day - p_first) % 7 = 0
              else p_day = p_first end
$$;

-- Koç bir günün görüşmesini işaretler: held | missed | cancelled | null (temizle).
create or replace function public.set_meeting_status(
  p_schedule uuid, p_day date, p_status text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_s public.meeting_schedules%rowtype;
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
begin
  select * into v_s from public.meeting_schedules where id = p_schedule;
  if not found or not public.is_coach_of(v_s.student_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if p_status is not null and p_status not in ('held', 'missed', 'cancelled') then
    raise exception 'INVALID_STATUS';
  end if;
  if not public.meeting_occurs_on(v_s.first_date, v_s.repeat_weekly, v_s.until_date, p_day) then
    raise exception 'NO_MEETING_THAT_DAY';
  end if;
  -- Yapıldı / yapılmadı gelecekteki bir gün için işaretlenemez (iptal edilebilir).
  if p_status in ('held', 'missed') and p_day > v_today then
    raise exception 'MEETING_IN_FUTURE';
  end if;

  insert into public.meeting_occurrences
    (schedule_id, occurs_on, student_id, status, marked_by, marked_at)
  values (v_s.id, p_day, v_s.student_id, p_status, auth.uid(), now())
  on conflict (schedule_id, occurs_on) do update
    set status = excluded.status,
        marked_by = excluded.marked_by,
        marked_at = excluded.marked_at;
end;
$$;
revoke execute on function public.set_meeting_status(uuid, date, text) from public, anon;
grant  execute on function public.set_meeting_status(uuid, date, text) to authenticated;

-- Yeni bildirim türü: öğrenciye "yarın görüşmen var".
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request', 'meeting'));

-- Görüşmesine 24 saatten az kalan öğrencilere hatırlatma. Aynı görüşme için
-- bir kez gönderilir; iptal edilen görüşme için gönderilmez. Kaç bildirim
-- gönderildiğini döndürür. [p_now] yalnızca test içindir.
create or replace function public.send_meeting_reminders(p_now timestamptz default now())
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_today date := (p_now at time zone 'Europe/Istanbul')::date;
  v_n int;
begin
  with due as (
    select s.id, s.coach_id, s.student_id, d.day,
           ((d.day + s.start_time) at time zone 'Europe/Istanbul') as at
    from public.meeting_schedules s
    cross join lateral (
      select (v_today + i) as day from generate_series(0, 2) i
    ) d
    where public.meeting_occurs_on(s.first_date, s.repeat_weekly, s.until_date, d.day)
  ), fresh as (
    select due.* from due
    left join public.meeting_occurrences o
      on o.schedule_id = due.id and o.occurs_on = due.day
    where due.at > p_now
      and due.at <= p_now + interval '24 hours'
      and o.reminded_at is null
      and o.status is distinct from 'cancelled'
  ), marked as (
    insert into public.meeting_occurrences (schedule_id, occurs_on, student_id, reminded_at)
    select id, day, student_id, p_now from fresh
    on conflict (schedule_id, occurs_on) do update
      set reminded_at = excluded.reminded_at
    returning schedule_id, occurs_on
  )
  insert into public.notifications (user_id, kind, data, ref_id)
  select f.student_id, 'meeting',
         jsonb_build_object('coach', p.full_name, 'at', f.at, 'route', '/student'),
         f.id
  from fresh f
  join marked m on m.schedule_id = f.id and m.occurs_on = f.day
  left join public.profiles p on p.id = f.coach_id;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.send_meeting_reminders(timestamptz) from public, anon, authenticated;

-- Zamanlayıcı: Supabase'de pg_cron ile 10 dakikada bir. Yerel testte
-- (PGlite) pg_cron olmadığı için atlanır.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('meeting-reminders', '*/10 * * * *',
                          'select public.send_meeting_reminders()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); hatırlatmalar zamanlanmadı';
  end if;
end;
$$;
