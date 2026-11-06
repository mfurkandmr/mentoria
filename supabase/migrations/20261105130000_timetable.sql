-- =====================================================================
-- Otomatik haftalık ders programı
-- ---------------------------------------------------------------------
-- Kurum müdürü öğretmenleri, sınıfları, derslikleri, ders saati şablonunu
-- ve sınıfların haftalık ders ihtiyacını girer; program uygulamada (Dart,
-- lib/features/schedule_generator/domain) üretilir ve buraya yazılır.
--
--  * teachers: kurumun öğretmenleri (uygulama hesabı olmayabilir;
--    profile_id doluysa o koç hesabı programını kendi panelinde görür).
--  * teacher_availability: müsait aralıklar. Satırı olmayan öğretmen her
--    saat müsait sayılır.
--  * classrooms (+ classroom_students), rooms, time_slots.
--  * class_lessons: sınıfın bir dersten haftalık saati; teacher_id doluysa
--    o öğretmen kesin, boşsa o branşa giren biri seçilir.
--  * schedules / schedule_entries: taslak ya da yayındaki program. Aynı
--    saatte öğretmen, sınıf ve derslik çakışması tekil indekslerle
--    engellenir. Kurumda en çok bir program yayında olur.
--  * Yazma/okuma: yalnızca kurum müdürü (tablolara doğrudan). Öğretmen,
--    öğrenci ve veli yayındaki programdan kendilerini ilgilendireni
--    my_timetable() ile görür.
--  * org_id ve tenant_id sunucuda yazılır; başka kurumun kaydına bağlantı
--    TIMETABLE_BAD_REF ile reddedilir.
--
-- Geri almak için: supabase/rollbacks/20261105130000_timetable.down.sql
-- =====================================================================

create or replace function public.is_org_admin(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and p.org_id = p_org)
$$;
revoke all on function public.is_org_admin(uuid) from public, anon;
grant execute on function public.is_org_admin(uuid) to authenticated;

create table public.rooms (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  name       text not null check (length(trim(name)) between 1 and 60),
  capacity   smallint check (capacity between 1 and 1000),
  created_at timestamptz not null default now()
);
create index on public.rooms (org_id);

create table public.teachers (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations (id) on delete cascade,
  tenant_id        uuid not null references public.tenants (id),
  full_name        text not null check (length(trim(full_name)) between 1 and 80),
  branches         text[] not null default '{}'
                   check (cardinality(branches) between 1 and 8),
  max_weekly_hours smallint not null default 30 check (max_weekly_hours between 1 and 80),
  profile_id       uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now()
);
create index on public.teachers (org_id);
create index on public.teachers (profile_id);

create table public.teacher_availability (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  teacher_id uuid not null references public.teachers (id) on delete cascade,
  day        smallint not null check (day between 1 and 7),
  start_time time not null,
  end_time   time not null,
  check (end_time > start_time)
);
create index on public.teacher_availability (teacher_id);
create index on public.teacher_availability (org_id);

create table public.classrooms (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  tenant_id    uuid not null references public.tenants (id),
  name         text not null check (length(trim(name)) between 1 and 60),
  level        text check (level in ('9', '10', '11', '12', 'graduate')),
  field        public.field_type,
  home_room_id uuid references public.rooms (id) on delete set null,
  created_at   timestamptz not null default now()
);
create index on public.classrooms (org_id);
create index on public.classrooms (home_room_id);

create table public.classroom_students (
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  student_id   uuid not null references public.profiles (id) on delete cascade,
  org_id       uuid not null references public.organizations (id) on delete cascade,
  tenant_id    uuid not null references public.tenants (id),
  primary key (classroom_id, student_id)
);
create index on public.classroom_students (student_id);
create index on public.classroom_students (org_id);

create table public.time_slots (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  day        smallint not null check (day between 1 and 7),
  seq        smallint not null check (seq between 1 and 20),
  start_time time not null,
  end_time   time not null,
  check (end_time > start_time),
  unique (org_id, day, seq)
);

create table public.class_lessons (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  tenant_id    uuid not null references public.tenants (id),
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  branch       text not null check (length(trim(branch)) between 1 and 40),
  weekly_hours smallint not null check (weekly_hours between 1 and 40),
  teacher_id   uuid references public.teachers (id) on delete set null,
  max_per_day  smallint not null default 2 check (max_per_day between 1 and 10),
  unique (classroom_id, branch)
);
create index on public.class_lessons (org_id);
create index on public.class_lessons (teacher_id);

create table public.schedules (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  name       text not null check (length(trim(name)) between 1 and 80),
  term       text check (length(term) <= 40),
  status     text not null default 'draft' check (status in ('draft', 'published')),
  soft_score integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.schedules (org_id, created_at desc);
create unique index schedules_one_published on public.schedules (org_id)
  where status = 'published';

create table public.schedule_entries (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  tenant_id    uuid not null references public.tenants (id),
  schedule_id  uuid not null references public.schedules (id) on delete cascade,
  teacher_id   uuid not null references public.teachers (id) on delete cascade,
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  room_id      uuid references public.rooms (id) on delete set null,
  time_slot_id uuid not null references public.time_slots (id) on delete cascade,
  branch       text not null check (length(trim(branch)) between 1 and 40),
  locked       boolean not null default false
);
-- Sert kısıtlar 1-3: aynı saatte öğretmen, sınıf ve derslik tek.
create unique index schedule_entries_teacher_slot
  on public.schedule_entries (schedule_id, time_slot_id, teacher_id);
create unique index schedule_entries_class_slot
  on public.schedule_entries (schedule_id, time_slot_id, classroom_id);
create unique index schedule_entries_room_slot
  on public.schedule_entries (schedule_id, time_slot_id, room_id)
  where room_id is not null;
create index on public.schedule_entries (org_id);
create index on public.schedule_entries (teacher_id);
create index on public.schedule_entries (classroom_id);
create index on public.schedule_entries (room_id);
create index on public.schedule_entries (time_slot_id);

-- Kurum (org_id, tenant_id) sunucuda yazılır, sonradan değişmez; bağlanan
-- kayıtlar aynı kurumdan olmalı.
create or replace function public.guard_timetable_row()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid;
  j jsonb := to_jsonb(new);
begin
  if tg_op = 'UPDATE' then
    v_org := old.org_id;
  elsif tg_table_name in ('rooms', 'teachers', 'classrooms', 'time_slots', 'schedules') then
    v_org := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  elsif tg_table_name = 'teacher_availability' then
    v_org := (select org_id from public.teachers where id = (j ->> 'teacher_id')::uuid);
  elsif tg_table_name in ('classroom_students', 'class_lessons') then
    v_org := (select org_id from public.classrooms where id = (j ->> 'classroom_id')::uuid);
  elsif tg_table_name = 'schedule_entries' then
    v_org := (select org_id from public.schedules where id = (j ->> 'schedule_id')::uuid);
  end if;
  -- Doğrudan istekte çağıran o kurumun müdürü olmalı (RLS de denetler;
  -- burada başka kurumun üst kaydına iliştirmeyi de keser).
  if v_org is null or (auth.uid() is not null and not public.is_org_admin(v_org)) then
    raise exception 'TIMETABLE_NOT_ADMIN';
  end if;
  new.org_id := v_org;
  new.tenant_id := (select tenant_id from public.organizations where id = v_org);

  if (j ? 'teacher_id') and j ->> 'teacher_id' is not null
     and not exists (select 1 from public.teachers
                     where id = (j ->> 'teacher_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'classroom_id') and j ->> 'classroom_id' is not null
     and not exists (select 1 from public.classrooms
                     where id = (j ->> 'classroom_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'room_id') and j ->> 'room_id' is not null
     and not exists (select 1 from public.rooms
                     where id = (j ->> 'room_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'home_room_id') and j ->> 'home_room_id' is not null
     and not exists (select 1 from public.rooms
                     where id = (j ->> 'home_room_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if (j ? 'time_slot_id') and j ->> 'time_slot_id' is not null
     and not exists (select 1 from public.time_slots
                     where id = (j ->> 'time_slot_id')::uuid and org_id = v_org) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if tg_table_name = 'teachers' and j ->> 'profile_id' is not null
     and not exists (select 1 from public.profiles
                     where id = (j ->> 'profile_id')::uuid and org_id = v_org
                       and role in ('coach', 'admin')) then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if tg_table_name = 'classroom_students'
     and not exists (select 1 from public.profiles
                     where id = (j ->> 'student_id')::uuid and org_id = v_org
                       and role = 'student') then
    raise exception 'TIMETABLE_BAD_REF';
  end if;
  if tg_table_name = 'teachers' then
    new.full_name := trim(j ->> 'full_name');
  end if;
  if tg_table_name = 'schedules' then
    new.updated_at := now();
    if tg_op = 'INSERT' then
      new.created_at := now();
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_timetable_row() from public, anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array['rooms', 'teachers', 'teacher_availability',
                           'classrooms', 'classroom_students', 'time_slots',
                           'class_lessons', 'schedules', 'schedule_entries'] loop
    execute format('create trigger guard_timetable_row before insert or update on public.%I
                    for each row execute function public.guard_timetable_row()', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "org admin manages" on public.%I for all to authenticated
                    using ((select public.is_org_admin(org_id)))
                    with check ((select public.is_org_admin(org_id)))', t);
    execute format('create policy "tenant isolation" on public.%I as restrictive for all to public
                    using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
                    with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke truncate, trigger, references on public.%I from authenticated', t);
  end loop;
end;
$$;

-- Programı tek seferde yazar (eski kayıtların hepsi silinir). p_entries:
-- [{teacher_id, classroom_id, room_id, time_slot_id, branch, locked}].
create or replace function public.save_schedule_entries(
  p_schedule uuid, p_entries jsonb, p_soft_score integer default null)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.schedules where id = p_schedule);
  v_n int;
begin
  if v_org is null or not public.is_org_admin(v_org) then
    raise exception 'TIMETABLE_NOT_ADMIN';
  end if;
  if jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) > 5000 then
    raise exception 'TIMETABLE_BAD_INPUT';
  end if;
  delete from public.schedule_entries where schedule_id = p_schedule;
  insert into public.schedule_entries
    (schedule_id, teacher_id, classroom_id, room_id, time_slot_id, branch, locked)
  select p_schedule, (e ->> 'teacher_id')::uuid, (e ->> 'classroom_id')::uuid,
         nullif(e ->> 'room_id', '')::uuid, (e ->> 'time_slot_id')::uuid,
         e ->> 'branch', coalesce((e ->> 'locked')::boolean, false)
  from jsonb_array_elements(p_entries) e;
  get diagnostics v_n = row_count;
  update public.schedules set soft_score = p_soft_score where id = p_schedule;
  return v_n;
end;
$$;
revoke all on function public.save_schedule_entries(uuid, jsonb, integer) from public, anon;
grant execute on function public.save_schedule_entries(uuid, jsonb, integer) to authenticated;

-- Yayınla: kurumdaki öteki yayındaki program taslağa döner.
create or replace function public.publish_schedule(p_schedule uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.schedules where id = p_schedule);
begin
  if v_org is null or not public.is_org_admin(v_org) then
    raise exception 'TIMETABLE_NOT_ADMIN';
  end if;
  update public.schedules set status = 'draft'
  where org_id = v_org and status = 'published' and id <> p_schedule;
  update public.schedules set status = 'published' where id = p_schedule;
end;
$$;
revoke all on function public.publish_schedule(uuid) from public, anon;
grant execute on function public.publish_schedule(uuid) to authenticated;

-- Yayındaki programdan beni ilgilendirenler: öğretmen (teachers.profile_id)
-- kendi dersleri, öğrenci kendi sınıf(lar)ı, veli çocuklarının sınıfları.
-- student_id: dersin hangi öğrenci için listelendiği (öğretmende null).
create or replace function public.my_timetable()
returns table (
  student_id     uuid,
  schedule_name  text,
  day            smallint,
  seq            smallint,
  start_time     time,
  end_time       time,
  branch         text,
  classroom_name text,
  teacher_name   text,
  room_name      text
)
language sql stable security definer set search_path = ''
as $$
  with mine as (
    select e.id entry_id, null::uuid sid
    from public.schedule_entries e
    join public.teachers t on t.id = e.teacher_id
    where t.profile_id = auth.uid()
    union
    select e.id, cs.student_id
    from public.schedule_entries e
    join public.classroom_students cs on cs.classroom_id = e.classroom_id
    where cs.student_id = auth.uid()
       or cs.student_id in (select ps.student_id from public.parent_students ps
                            where ps.parent_id = auth.uid())
  )
  select m.sid, s.name, ts.day, ts.seq, ts.start_time, ts.end_time, e.branch,
         c.name, t.full_name, r.name
  from mine m
  join public.schedule_entries e on e.id = m.entry_id
  join public.schedules s on s.id = e.schedule_id and s.status = 'published'
  join public.time_slots ts on ts.id = e.time_slot_id
  join public.classrooms c on c.id = e.classroom_id
  join public.teachers t on t.id = e.teacher_id
  left join public.rooms r on r.id = e.room_id
  order by m.sid nulls first, ts.day, ts.seq
$$;
revoke all on function public.my_timetable() from public, anon;
grant execute on function public.my_timetable() to authenticated;
