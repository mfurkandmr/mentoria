-- =====================================================================
-- Ödev paketleri ve bildirimler
--  * Koç (veya müdür) öğrenciye ders/konu "sepeti" halinde ödev yollar.
--  * Öğrenci yalnızca maddelerin "yapıldı" durumunu değiştirebilir.
--  * Ödev, deneme sonucu, görev ve koç notu gelince öğrenciye bildirim düşer.
-- =====================================================================

create table public.assignments (
  id         uuid primary key default gen_random_uuid(),
  coach_id   uuid references public.profiles (id) on delete set null,
  student_id uuid not null references public.profiles (id) on delete cascade,
  title      text not null check (length(trim(title)) between 1 and 120),
  note       text check (length(note) <= 1000),
  due_on     date,
  created_at timestamptz not null default now()
);
create index on public.assignments (student_id, created_at desc);
create index on public.assignments (coach_id);

create table public.assignment_items (
  id             uuid primary key default gen_random_uuid(),
  assignment_id  uuid not null references public.assignments (id) on delete cascade,
  subject_id     smallint not null references public.subjects (id),
  topic_id       int references public.topics (id),
  question_count int check (question_count between 1 and 1000),
  note           text check (length(note) <= 300),
  sort           int not null default 0,
  done           boolean not null default false,
  done_at        timestamptz
);
create index on public.assignment_items (assignment_id, sort);
create index on public.assignment_items (topic_id);
create index on public.assignment_items (subject_id);

create or replace function public.stamp_item_done()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.done_at := case when new.done then coalesce(old.done_at, now()) end;
  return new;
end;
$$;

create trigger assignment_items_done
  before update on public.assignment_items
  for each row execute function public.stamp_item_done();

alter table public.assignments      enable row level security;
alter table public.assignment_items enable row level security;

create policy "view assignments" on public.assignments
  for select to authenticated using (public.can_view_student(student_id));
create policy "manager deletes assignments" on public.assignments
  for delete to authenticated using (public.can_manage_student(student_id));

create policy "view assignment items" on public.assignment_items
  for select to authenticated using (
    exists (select 1 from public.assignments a
            where a.id = assignment_id and public.can_view_student(a.student_id)));
create policy "student or manager ticks items" on public.assignment_items
  for update to authenticated
  using (exists (select 1 from public.assignments a
                 where a.id = assignment_id
                   and (a.student_id = (select auth.uid())
                        or public.can_manage_student(a.student_id))))
  with check (exists (select 1 from public.assignments a
                      where a.id = assignment_id
                        and (a.student_id = (select auth.uid())
                             or public.can_manage_student(a.student_id))));

-- Ekleme yalnızca send_assignment ile (paket ve maddeleri tek seferde).
revoke insert, update on public.assignments from anon, authenticated;
revoke insert, update on public.assignment_items from anon, authenticated;
grant update (done) on public.assignment_items to authenticated;

-- ---------------------------------------------------------------------
-- Bildirimler
-- ---------------------------------------------------------------------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in ('assignment', 'exam', 'task', 'note')),
  -- Metin istemcide kullanıcının dilinde üretilir; burada yalnızca veriler.
  data       jsonb not null default '{}',
  ref_id     uuid,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;
create policy "own notifications" on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));
create policy "mark own notifications read" on public.notifications
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "delete own notifications" on public.notifications
  for delete to authenticated using (user_id = (select auth.uid()));

revoke insert, update on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

create or replace function public.notify(
  p_user uuid, p_kind text, p_data jsonb, p_ref uuid)
returns void
language sql security definer set search_path = ''
as $$
  insert into public.notifications (user_id, kind, data, ref_id)
  values (p_user, p_kind, p_data, p_ref)
$$;
revoke execute on function public.notify(uuid, text, jsonb, uuid) from public, anon, authenticated;

-- Ödev gönderme: paket + maddeler + bildirim, hepsi ya da hiçbiri.
-- p_items: [{"subject_code": "TYT_MAT", "topic_id": 12, "question_count": 20, "note": "..."}]
create or replace function public.send_assignment(
  p_student uuid,
  p_title   text,
  p_items   jsonb,
  p_due_on  date default null,
  p_note    text default null)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_id     uuid;
  v_count  int;
  v_sender text;
begin
  if not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  v_count := coalesce(jsonb_array_length(p_items), 0);
  if v_count = 0 then
    raise exception 'EMPTY_ASSIGNMENT';
  end if;
  if v_count > 50 then
    raise exception 'TOO_MANY_ITEMS';
  end if;

  insert into public.assignments (coach_id, student_id, title, note, due_on)
  values (auth.uid(), p_student, trim(p_title), nullif(trim(p_note), ''), p_due_on)
  returning id into v_id;

  insert into public.assignment_items
    (assignment_id, subject_id, topic_id, question_count, note, sort)
  select v_id, s.id, t.id, (i.value ->> 'question_count')::int,
         nullif(trim(i.value ->> 'note'), ''), i.ordinality::int
  from jsonb_array_elements(p_items) with ordinality as i
  join public.subjects s on s.code = i.value ->> 'subject_code'
  -- Konu verildiyse o derse ait olmalı.
  left join public.topics t
    on t.id = (i.value ->> 'topic_id')::int and t.subject_id = s.id;

  get diagnostics v_count = row_count;
  if v_count <> jsonb_array_length(p_items) then
    raise exception 'INVALID_SUBJECT';
  end if;

  select full_name into v_sender from public.profiles where id = auth.uid();
  perform public.notify(p_student, 'assignment',
    jsonb_build_object('title', trim(p_title), 'items', v_count, 'from', v_sender),
    v_id);
  return v_id;
end;
$$;
revoke execute on function public.send_assignment(uuid, text, jsonb, date, text) from public, anon;
grant  execute on function public.send_assignment(uuid, text, jsonb, date, text) to authenticated;

-- Deneme sonucu, görev ve not eklenince öğrenciye haber ver
-- (öğrencinin kendi eklediği kayıt için bildirim yok).
create or replace function public.notify_student_on_insert()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.student_id = auth.uid() then
    return new;
  end if;
  if tg_table_name = 'exams' then
    perform public.notify(new.student_id, 'exam',
      jsonb_build_object('name', new.name, 'type', new.exam_type), new.id);
  elsif tg_table_name = 'tasks' then
    perform public.notify(new.student_id, 'task',
      jsonb_build_object('title', new.title), new.id);
  elsif tg_table_name = 'coach_notes' then
    perform public.notify(new.student_id, 'note',
      jsonb_build_object('body', left(new.body, 140)), new.id);
  end if;
  return new;
end;
$$;
revoke execute on function public.notify_student_on_insert() from public, anon, authenticated;

create trigger notify_exam after insert on public.exams
  for each row execute function public.notify_student_on_insert();
create trigger notify_task after insert on public.tasks
  for each row execute function public.notify_student_on_insert();
create trigger notify_note after insert on public.coach_notes
  for each row execute function public.notify_student_on_insert();

-- Uygulama açıkken bildirimlerin anında gelmesi için (Supabase Realtime).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;
