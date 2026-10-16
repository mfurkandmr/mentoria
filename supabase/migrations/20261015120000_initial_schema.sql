-- =====================================================================
-- Mentoria · İlk şema
-- Roller: admin (kurum müdürü), coach, student, parent
-- Kayıt yalnızca davet koduyla (handle_new_user tetikleyicisi).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tipler
-- ---------------------------------------------------------------------
create type public.user_role as enum ('admin', 'coach', 'student', 'parent');
create type public.exam_type as enum ('TYT', 'AYT', 'YDT');
create type public.field_type as enum ('SAY', 'EA', 'SOZ', 'DIL');
create type public.topic_status as enum ('not_started', 'in_progress', 'done', 'review');
create type public.session_type as enum ('pomodoro', 'free');
create type public.task_status as enum ('pending', 'done', 'skipped');

-- ---------------------------------------------------------------------
-- Kurum ve kullanıcılar
-- ---------------------------------------------------------------------
create table public.organizations (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  type               text not null default 'institution'
                     check (type in ('institution', 'solo_coach')),
  seat_limit         int  not null default 0 check (seat_limit >= 0),  -- öğrenci lisans sayısı
  license_expires_at timestamptz,
  created_at         timestamptz not null default now()
);

create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  full_name       text not null,
  role            public.user_role not null,
  org_id          uuid references public.organizations (id) on delete set null,
  avatar_url      text,
  exam_year       int,
  field           public.field_type,
  kvkk_consent_at timestamptz,
  created_at      timestamptz not null default now()
);
create index on public.profiles (org_id, role);

create table public.coach_students (
  coach_id   uuid not null references public.profiles (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  org_id     uuid not null references public.organizations (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (coach_id, student_id)
);
create index on public.coach_students (student_id);

create table public.parent_students (
  parent_id  uuid not null references public.profiles (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (parent_id, student_id)
);
create index on public.parent_students (student_id);

-- Davet kodları:
--   admin   → org_id
--   coach   → org_id
--   student → org_id + coach_id (öğrencinin bağlanacağı koç)
--   parent  → org_id + student_id
create table public.invite_codes (
  code        text primary key,
  org_id      uuid not null references public.organizations (id) on delete cascade,
  target_role public.user_role not null,
  coach_id    uuid references public.profiles (id) on delete cascade,
  student_id  uuid references public.profiles (id) on delete cascade,
  created_by  uuid references public.profiles (id) on delete set null,
  max_uses    int not null default 1 check (max_uses > 0),
  used_count  int not null default 0,
  expires_at  timestamptz not null default now() + interval '14 days',
  created_at  timestamptz not null default now(),
  check (target_role <> 'student' or coach_id is not null),
  check (target_role <> 'parent' or student_id is not null)
);

-- ---------------------------------------------------------------------
-- Müfredat (referans veriler)
-- ---------------------------------------------------------------------
create table public.subjects (
  id             smallint generated always as identity primary key,
  code           text unique not null,     -- Flutter: core/constants/exam_subjects.dart
  exam_type      public.exam_type not null,
  name           text not null,
  question_count int  not null,
  sort           int  not null default 0
);

create table public.topics (
  id         int generated always as identity primary key,
  subject_id smallint not null references public.subjects (id) on delete cascade,
  parent_id  int references public.topics (id) on delete cascade,
  name       text not null,
  sort       int  not null default 0
);
create index on public.topics (subject_id);

-- ---------------------------------------------------------------------
-- Öğrenci verileri
-- ---------------------------------------------------------------------
create table public.exams (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles (id) on delete cascade,
  exam_type  public.exam_type not null,
  field      public.field_type,             -- AYT için
  name       text not null,
  publisher  text,
  taken_on   date not null default current_date,
  created_at timestamptz not null default now()
);
create index on public.exams (student_id, taken_on desc);

create table public.exam_subject_results (
  exam_id    uuid not null references public.exams (id) on delete cascade,
  subject_id smallint not null references public.subjects (id),
  correct    int not null default 0 check (correct >= 0),
  wrong      int not null default 0 check (wrong >= 0),
  blank      int not null default 0 check (blank >= 0),
  net        numeric(6, 2) generated always as (correct - wrong / 4.0) stored,
  primary key (exam_id, subject_id)
);

create table public.exam_wrong_topics (
  exam_id  uuid not null references public.exams (id) on delete cascade,
  topic_id int  not null references public.topics (id),
  count    int  not null default 1 check (count > 0),
  primary key (exam_id, topic_id)
);

create table public.question_logs (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles (id) on delete cascade,
  subject_id smallint not null references public.subjects (id),
  topic_id   int references public.topics (id),
  correct    int not null default 0 check (correct >= 0),
  wrong      int not null default 0 check (wrong >= 0),
  blank      int not null default 0 check (blank >= 0),
  logged_on  date not null default current_date,
  source     text,                           -- kitap / yayın adı
  created_at timestamptz not null default now()
);
create index on public.question_logs (student_id, logged_on desc);

create table public.topic_progress (
  student_id uuid not null references public.profiles (id) on delete cascade,
  topic_id   int  not null references public.topics (id) on delete cascade,
  status     public.topic_status not null default 'not_started',
  updated_at timestamptz not null default now(),
  primary key (student_id, topic_id)
);

create table public.study_sessions (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.profiles (id) on delete cascade,
  subject_id   smallint references public.subjects (id),
  type         public.session_type not null default 'pomodoro',
  started_at   timestamptz not null,
  duration_sec int not null check (duration_sec > 0 and duration_sec <= 43200),
  created_at   timestamptz not null default now()
);
create index on public.study_sessions (student_id, started_at desc);

create table public.goals (
  student_id        uuid primary key references public.profiles (id) on delete cascade,
  daily_questions   int,
  daily_minutes     int,
  target_university text,
  target_department text,
  target_rank       int,
  updated_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Koç araçları
-- ---------------------------------------------------------------------
create table public.tasks (
  id               uuid primary key default gen_random_uuid(),
  coach_id         uuid not null references public.profiles (id) on delete cascade,
  student_id       uuid not null references public.profiles (id) on delete cascade,
  title            text not null,
  description      text,
  subject_id       smallint references public.subjects (id),
  topic_id         int references public.topics (id),
  target_questions int,
  due_on           date,
  status           public.task_status not null default 'pending',
  completed_at     timestamptz,
  created_at       timestamptz not null default now()
);
create index on public.tasks (student_id, due_on);

create table public.coach_notes (
  id         uuid primary key default gen_random_uuid(),
  coach_id   uuid not null references public.profiles (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now()
);
create index on public.coach_notes (student_id, created_at desc);

-- ---------------------------------------------------------------------
-- Puan / sıralama tahmini (her yıl ÖSYM verisiyle güncellenir)
-- ---------------------------------------------------------------------
create table public.score_types (
  year       int  not null,
  score_type text not null,                  -- TYT, SAY, EA, SOZ, DIL
  base_score numeric(8, 4) not null,
  primary key (year, score_type)
);

create table public.score_coefficients (
  year        int  not null,
  score_type  text not null,
  subject_id  smallint not null references public.subjects (id),
  coefficient numeric(8, 4) not null,
  primary key (year, score_type, subject_id),
  foreign key (year, score_type) references public.score_types (year, score_type) on delete cascade
);

create table public.rank_tables (
  year       int  not null,
  score_type text not null,
  score      numeric(8, 3) not null,
  rank       int  not null,
  primary key (year, score_type, score)
);

-- =====================================================================
-- Yardımcı fonksiyonlar (RLS içinde özyinelemeyi önlemek için SECURITY DEFINER)
-- =====================================================================
create or replace function public.my_role()
returns public.user_role
language sql stable security definer set search_path = ''
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.my_org()
returns uuid
language sql stable security definer set search_path = ''
as $$ select org_id from public.profiles where id = auth.uid() $$;

create or replace function public.is_coach_of(p_student uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.coach_students
    where coach_id = auth.uid() and student_id = p_student
  )
$$;

create or replace function public.is_admin_of_user(p_user uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles me
    join public.profiles target on target.org_id = me.org_id
    where me.id = auth.uid() and me.role = 'admin' and target.id = p_user
  )
$$;

-- Öğrenci verisini kim görebilir: kendisi, koçu, velisi, kurum müdürü.
create or replace function public.can_view_student(p_student uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select p_student = auth.uid()
      or public.is_coach_of(p_student)
      or exists (
           select 1 from public.parent_students
           where parent_id = auth.uid() and student_id = p_student
         )
      or public.is_admin_of_user(p_student)
$$;

-- =====================================================================
-- Kayıt: davet kodu doğrulama + profil oluşturma
-- =====================================================================

-- Kayıt ekranında kodu önceden doğrulamak için (giriş yapmamış kullanıcı çağırır).
create or replace function public.check_invite(p_code text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object('role', i.target_role, 'org_name', o.name)
  from public.invite_codes i
  join public.organizations o on o.id = i.org_id
  where i.code = upper(trim(p_code))
    and i.expires_at > now()
    and i.used_count < i.max_uses
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_code   text := upper(trim(new.raw_user_meta_data ->> 'invite_code'));
  v_name   text := trim(new.raw_user_meta_data ->> 'full_name');
  v_invite public.invite_codes%rowtype;
  v_seats  int;
  v_used   int;
begin
  if v_code is null or v_code = '' then
    raise exception 'INVITE_REQUIRED';
  end if;
  if v_name is null or length(v_name) < 3 then
    raise exception 'NAME_REQUIRED';
  end if;

  select * into v_invite
  from public.invite_codes
  where code = v_code
  for update;

  if not found
     or v_invite.expires_at <= now()
     or v_invite.used_count >= v_invite.max_uses then
    raise exception 'INVITE_INVALID';
  end if;

  -- Öğrenci lisans kotası kontrolü
  if v_invite.target_role = 'student' then
    select seat_limit into v_seats
    from public.organizations
    where id = v_invite.org_id
      and (license_expires_at is null or license_expires_at > now());
    if not found then
      raise exception 'LICENSE_EXPIRED';
    end if;

    select count(*) into v_used
    from public.profiles
    where org_id = v_invite.org_id and role = 'student';
    if v_used >= v_seats then
      raise exception 'SEAT_LIMIT_REACHED';
    end if;
  end if;

  insert into public.profiles (id, full_name, role, org_id, kvkk_consent_at)
  values (
    new.id,
    v_name,
    v_invite.target_role,
    v_invite.org_id,
    case when (new.raw_user_meta_data ->> 'kvkk_consent')::boolean then now() end
  );

  if v_invite.target_role = 'student' then
    insert into public.coach_students (coach_id, student_id, org_id)
    values (v_invite.coach_id, new.id, v_invite.org_id);
  elsif v_invite.target_role = 'parent' then
    insert into public.parent_students (parent_id, student_id)
    values (new.id, v_invite.student_id);
  end if;

  update public.invite_codes
  set used_count = used_count + 1
  where code = v_code;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Davet kodu üretimi (uygulamadan çağrılır).
--   admin   → coach ya da student kodu (student için p_coach zorunlu)
--   coach   → kendi öğrencisi için student kodu
--   student → kendi velisi için parent kodu
create or replace function public.create_invite(
  p_target_role public.user_role,
  p_coach uuid default null,
  p_max_uses int default 1
)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_me      public.profiles%rowtype;
  v_code    text;
  v_coach   uuid;
  v_student uuid;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if v_me.role = 'admin' and p_target_role = 'coach' then
    null;
  elsif v_me.role = 'admin' and p_target_role = 'student' then
    if not exists (
      select 1 from public.profiles
      where id = p_coach and role = 'coach' and org_id = v_me.org_id
    ) then
      raise exception 'COACH_NOT_IN_ORG';
    end if;
    v_coach := p_coach;
  elsif v_me.role = 'coach' and p_target_role = 'student' then
    v_coach := v_me.id;
  elsif v_me.role = 'student' and p_target_role = 'parent' then
    v_student := v_me.id;
  else
    raise exception 'NOT_ALLOWED';
  end if;

  -- Karışan karakterler (0/O, 1/I) olmadan 8 haneli kod
  loop
    select string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
    into v_code
    from generate_series(1, 8);
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;

  insert into public.invite_codes
    (code, org_id, target_role, coach_id, student_id, created_by, max_uses)
  values
    (v_code, v_me.org_id, p_target_role, v_coach, v_student, v_me.id,
     greatest(1, least(p_max_uses, 200)));

  return v_code;
end;
$$;

-- Öğrenci görevin yalnızca durumunu değiştirebilir; içeriği koç belirler.
create or replace function public.guard_task_update()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() = old.student_id and auth.uid() <> old.coach_id then
    if (new.title, new.description, new.subject_id, new.topic_id,
        new.target_questions, new.due_on, new.coach_id, new.student_id)
       is distinct from
       (old.title, old.description, old.subject_id, old.topic_id,
        old.target_questions, old.due_on, old.coach_id, old.student_id) then
      raise exception 'STUDENT_CAN_ONLY_UPDATE_STATUS';
    end if;
  end if;
  new.completed_at := case when new.status = 'done' then coalesce(new.completed_at, now()) end;
  return new;
end;
$$;

create trigger tasks_guard
  before update on public.tasks
  for each row execute function public.guard_task_update();

-- =====================================================================
-- Row Level Security
-- =====================================================================
alter table public.organizations        enable row level security;
alter table public.profiles             enable row level security;
alter table public.coach_students       enable row level security;
alter table public.parent_students      enable row level security;
alter table public.invite_codes         enable row level security;
alter table public.subjects             enable row level security;
alter table public.topics               enable row level security;
alter table public.exams                enable row level security;
alter table public.exam_subject_results enable row level security;
alter table public.exam_wrong_topics    enable row level security;
alter table public.question_logs        enable row level security;
alter table public.topic_progress       enable row level security;
alter table public.study_sessions       enable row level security;
alter table public.goals                enable row level security;
alter table public.tasks                enable row level security;
alter table public.coach_notes          enable row level security;
alter table public.score_types          enable row level security;
alter table public.score_coefficients   enable row level security;
alter table public.rank_tables          enable row level security;

-- Kurum: üyeler okur; müdür yalnızca adını değiştirebilir (lisans alanları değil).
create policy "org members read" on public.organizations
  for select to authenticated using (id = public.my_org());
create policy "admin renames org" on public.organizations
  for update to authenticated
  using (id = public.my_org() and public.my_role() = 'admin')
  with check (id = public.my_org());
revoke update on public.organizations from authenticated;
grant update (name) on public.organizations to authenticated;

-- Profiller
create policy "read own and related profiles" on public.profiles
  for select to authenticated using (
    id = auth.uid()
    or public.can_view_student(id)
    or exists (                                         -- öğrenci koçunu görür
         select 1 from public.coach_students cs
         where cs.coach_id = profiles.id and cs.student_id = auth.uid()
       )
    or (org_id = public.my_org() and public.my_role() = 'admin')
  );
create policy "update own profile" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from authenticated;
grant update (full_name, avatar_url, exam_year, field, kvkk_consent_at)
  on public.profiles to authenticated;

-- Koç–öğrenci bağı: müdür yönetir (koç değiştirme), taraflar okur.
create policy "read coach links" on public.coach_students
  for select to authenticated using (
    coach_id = auth.uid() or student_id = auth.uid()
    or (org_id = public.my_org() and public.my_role() = 'admin')
  );
create policy "admin manages coach links" on public.coach_students
  for all to authenticated
  using (org_id = public.my_org() and public.my_role() = 'admin')
  with check (
    org_id = public.my_org() and public.my_role() = 'admin'
    and public.is_admin_of_user(coach_id) and public.is_admin_of_user(student_id)
  );

-- Veli–öğrenci bağı: taraflar okur, öğrenci velisini kaldırabilir.
create policy "read parent links" on public.parent_students
  for select to authenticated using (
    parent_id = auth.uid() or student_id = auth.uid()
    or public.is_coach_of(student_id) or public.is_admin_of_user(student_id)
  );
create policy "student removes parent" on public.parent_students
  for delete to authenticated using (student_id = auth.uid());

-- Davet kodları: oluşturan ve müdür görür; üretim create_invite() ile.
create policy "read own invites" on public.invite_codes
  for select to authenticated using (
    created_by = auth.uid()
    or (org_id = public.my_org() and public.my_role() = 'admin')
  );
create policy "delete own invites" on public.invite_codes
  for delete to authenticated using (
    created_by = auth.uid()
    or (org_id = public.my_org() and public.my_role() = 'admin')
  );

-- Referans tablolar: herkes okur, kimse yazamaz (yalnızca service role).
create policy "read subjects" on public.subjects for select to authenticated using (true);
create policy "read topics" on public.topics for select to authenticated using (true);
create policy "read score types" on public.score_types for select to authenticated using (true);
create policy "read coefficients" on public.score_coefficients for select to authenticated using (true);
create policy "read rank tables" on public.rank_tables for select to authenticated using (true);

-- Öğrencinin kendi girdiği veriler: ilgili herkes okur, yalnızca öğrenci yazar.
create policy "view exams" on public.exams
  for select to authenticated using (public.can_view_student(student_id));
create policy "student writes exams" on public.exams
  for all to authenticated
  using (student_id = auth.uid()) with check (student_id = auth.uid());

create policy "view exam results" on public.exam_subject_results
  for select to authenticated using (
    exists (select 1 from public.exams e
            where e.id = exam_id and public.can_view_student(e.student_id))
  );
create policy "student writes exam results" on public.exam_subject_results
  for all to authenticated
  using (exists (select 1 from public.exams e where e.id = exam_id and e.student_id = auth.uid()))
  with check (exists (select 1 from public.exams e where e.id = exam_id and e.student_id = auth.uid()));

create policy "view exam wrong topics" on public.exam_wrong_topics
  for select to authenticated using (
    exists (select 1 from public.exams e
            where e.id = exam_id and public.can_view_student(e.student_id))
  );
create policy "student writes exam wrong topics" on public.exam_wrong_topics
  for all to authenticated
  using (exists (select 1 from public.exams e where e.id = exam_id and e.student_id = auth.uid()))
  with check (exists (select 1 from public.exams e where e.id = exam_id and e.student_id = auth.uid()));

create policy "view question logs" on public.question_logs
  for select to authenticated using (public.can_view_student(student_id));
create policy "student writes question logs" on public.question_logs
  for all to authenticated
  using (student_id = auth.uid()) with check (student_id = auth.uid());

create policy "view topic progress" on public.topic_progress
  for select to authenticated using (public.can_view_student(student_id));
create policy "student writes topic progress" on public.topic_progress
  for all to authenticated
  using (student_id = auth.uid()) with check (student_id = auth.uid());

create policy "view study sessions" on public.study_sessions
  for select to authenticated using (public.can_view_student(student_id));
create policy "student writes study sessions" on public.study_sessions
  for all to authenticated
  using (student_id = auth.uid()) with check (student_id = auth.uid());

-- Hedefler: öğrenci ve koçu yazabilir.
create policy "view goals" on public.goals
  for select to authenticated using (public.can_view_student(student_id));
create policy "student or coach writes goals" on public.goals
  for all to authenticated
  using (student_id = auth.uid() or public.is_coach_of(student_id))
  with check (student_id = auth.uid() or public.is_coach_of(student_id));

-- Görevler: koç oluşturur/siler, öğrenci durumunu günceller (tasks_guard).
create policy "view tasks" on public.tasks
  for select to authenticated using (public.can_view_student(student_id));
create policy "coach creates tasks" on public.tasks
  for insert to authenticated
  with check (coach_id = auth.uid() and public.is_coach_of(student_id));
create policy "coach or student updates tasks" on public.tasks
  for update to authenticated
  using (coach_id = auth.uid() or student_id = auth.uid())
  with check (coach_id = auth.uid() or student_id = auth.uid());
create policy "coach deletes tasks" on public.tasks
  for delete to authenticated using (coach_id = auth.uid());

-- Koç notları: koç yazar; öğrenci ve müdür okur (veli görmez).
create policy "view coach notes" on public.coach_notes
  for select to authenticated using (
    coach_id = auth.uid() or student_id = auth.uid()
    or public.is_admin_of_user(student_id)
  );
create policy "coach writes notes" on public.coach_notes
  for insert to authenticated
  with check (coach_id = auth.uid() and public.is_coach_of(student_id));
create policy "coach edits own notes" on public.coach_notes
  for update to authenticated
  using (coach_id = auth.uid()) with check (coach_id = auth.uid());
create policy "coach deletes own notes" on public.coach_notes
  for delete to authenticated using (coach_id = auth.uid());

-- Fonksiyon yetkileri
revoke execute on function public.check_invite(text) from public;
grant execute on function public.check_invite(text) to anon, authenticated;
revoke execute on function public.create_invite(public.user_role, uuid, int) from public, anon;
grant execute on function public.create_invite(public.user_role, uuid, int) to authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
