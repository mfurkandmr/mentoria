-- =====================================================================
-- Kitap takibi: kurum kitap havuzu, öğrencinin kitapları (dönem başına
-- sınırlı), çalışma kayıtları
-- ---------------------------------------------------------------------
--  * books: kurumun kaynak havuzu. Öğrenci yalnızca talep ekler (durum
--    zorla 'pending'); koç/müdür ekler, onaylar (approve_book), mevcut bir
--    kitapla birleştirir (merge_book_request) ya da reddeder
--    (reject_book_request). Talep eden öğrenciye 'book_request' bildirimi.
--    Kurum içinde ad + yayın tekil (büyük/küçük harf, Türkçe harf, boşluk
--    ve noktalama fark etmez).
--  * student_books: öğrencinin kitapları. Öğrenci yalnızca havuzdaki aktif
--    kitabı ekler, sonra değiştiremez/silemez. Dönem sunucuda (Eylül-Ocak
--    Güz, Şubat-Ağustos Bahar). Dönemde EKLENEN toplam kayıt sayılır (bitti
--    / bırakıldı da); sınır 7, student_book_limits ile koç/müdür artırır.
--    Koç/müdür silerse limitten düşer.
--  * book_progress: çalışma kaydı. Öğrenci ekler, kendi kaydını 24 saat
--    içinde düzenler/siler; koç/müdür her zaman. Doğru+yanlış+boş varsa
--    question_logs'a kitap adıyla yansır (istatistik, haftalık rapor).
--  * topic_gaps(öğrenci): denemede başarısı düşük ama son 60 günde kitapla
--    çalışılmamış konular (koç paneli sinyali).
--  * Veli: can_view_student ile yalnızca okur.
--
-- Geri almak için: supabase/rollbacks/20261105160000_student_books.down.sql
-- =====================================================================

-- "3D Yayınları " → "3dyayinlari" (eşleşme anahtarı).
create or replace function public.norm_key(p text)
returns text
language sql immutable set search_path = ''
as $$
  select regexp_replace(
    lower(translate(coalesce(p, ''), 'ÇĞİIÖŞÜÂÎÛçğıöşüâîû', 'cgiiosuaiucgiosuaiu')),
    '[^a-z0-9]', '', 'g')
$$;

-- Eğitim dönemi: Eylül-Ocak "2026-Güz", Şubat-Ağustos "2027-Bahar".
create or replace function public.term_of(p_day date)
returns text
language sql immutable set search_path = ''
as $$
  select case
    when extract(month from p_day) >= 9 then extract(year from p_day)::int || '-Güz'
    when extract(month from p_day) = 1 then (extract(year from p_day)::int - 1) || '-Güz'
    else extract(year from p_day)::int || '-Bahar'
  end
$$;

create or replace function public.current_term()
returns text
language sql stable set search_path = ''
as $$ select public.term_of((now() at time zone 'Europe/Istanbul')::date) $$;

create table public.books (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations (id) on delete cascade,
  tenant_id     uuid not null references public.tenants (id),
  name          text not null check (length(trim(name)) between 2 and 120),
  publisher     text not null check (length(trim(publisher)) between 1 and 80),
  subject_id    smallint references public.subjects (id),
  kind          text not null default 'question_bank'
                check (kind in ('question_bank', 'practice_exams', 'lecture', 'other')),
  status        text not null default 'active' check (status in ('active', 'pending', 'inactive')),
  requested_by  uuid references public.profiles (id) on delete set null,
  created_role  text,
  created_at    timestamptz not null default now(),
  name_key      text generated always as (public.norm_key(name)) stored,
  publisher_key text generated always as (public.norm_key(publisher)) stored
);
create unique index books_unique on public.books (org_id, name_key, publisher_key);
create index on public.books (org_id, status);
create index on public.books (tenant_id);
create index on public.books (requested_by);
create index on public.books (subject_id);

create table public.student_books (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.tenants (id),
  student_id  uuid not null references public.profiles (id) on delete cascade,
  book_id     uuid not null references public.books (id) on delete cascade,
  term        text not null,
  started_on  date not null default current_date,
  status      text not null default 'active' check (status in ('active', 'finished', 'dropped')),
  added_role  text,
  added_by    uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  unique (student_id, book_id, term)
);
create index on public.student_books (student_id, term);
create index on public.student_books (book_id);
create index on public.student_books (tenant_id);
create index on public.student_books (added_by);

create table public.student_book_limits (
  student_id  uuid not null references public.profiles (id) on delete cascade,
  term        text not null,
  tenant_id   uuid not null references public.tenants (id),
  book_limit  smallint not null check (book_limit between 1 and 50),
  reason      text check (length(reason) <= 300),
  changed_by  uuid references public.profiles (id) on delete set null,
  changed_at  timestamptz not null default now(),
  primary key (student_id, term)
);
create index on public.student_book_limits (tenant_id);
create index on public.student_book_limits (changed_by);

create table public.book_progress (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references public.tenants (id),
  student_book_id uuid not null references public.student_books (id) on delete cascade,
  student_id      uuid not null references public.profiles (id) on delete cascade,
  studied_on      date not null default current_date,
  topic_id        int references public.topics (id) on delete set null,
  topic_text      text check (length(topic_text) <= 120),
  page_from       int check (page_from > 0),
  page_to         int check (page_to > 0),
  questions       int check (questions between 0 and 2000),
  correct         int check (correct >= 0),
  wrong           int check (wrong >= 0),
  blank           int check (blank >= 0),
  note            text check (length(note) <= 500),
  entered_role    text,
  created_by      uuid references public.profiles (id) on delete set null,
  created_at      timestamptz not null default now(),
  question_log_id uuid references public.question_logs (id) on delete set null,
  check (page_to is null or page_from is null or page_to >= page_from),
  check (coalesce(correct, 0) + coalesce(wrong, 0) + coalesce(blank, 0)
         <= coalesce(questions, coalesce(correct, 0) + coalesce(wrong, 0) + coalesce(blank, 0)))
);
create index on public.book_progress (student_book_id, studied_on desc);
create index on public.book_progress (student_id, studied_on desc);
create index on public.book_progress (tenant_id);
create index on public.book_progress (topic_id);
create index on public.book_progress (created_by);
create index on public.book_progress (question_log_id);

-- ---------------------------------------------------------------------
-- Tetikleyiciler
-- ---------------------------------------------------------------------
create or replace function public.guard_book()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
begin
  if tg_op = 'UPDATE' then
    new.org_id := old.org_id;
    new.tenant_id := old.tenant_id;
    new.requested_by := old.requested_by;
    new.created_role := old.created_role;
    new.created_at := old.created_at;
    return new;
  end if;
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is not null then
    if v_me.role not in ('student', 'coach', 'admin') or v_me.org_id is null then
      raise exception 'NOT_ALLOWED';
    end if;
    new.org_id := v_me.org_id;
    new.created_role := v_me.role::text;
    if v_me.role = 'student' then
      -- Öğrenci havuza doğrudan ekleyemez: yalnızca talep.
      new.status := 'pending';
      new.requested_by := v_me.id;
    else
      new.requested_by := null;
    end if;
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);
  new.name := trim(new.name);
  new.publisher := trim(new.publisher);
  new.created_at := now();
  return new;
end;
$$;
revoke all on function public.guard_book() from public, anon, authenticated;
create trigger guard_book before insert or update on public.books
  for each row execute function public.guard_book();

-- Öğrencinin kitabı: dönem sunucuda, kitap aktif ve aynı kurumdan, dönem
-- sınırı (eklenen toplam kayıt).
create or replace function public.guard_student_book()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_student public.profiles%rowtype;
  v_role    text := (select role::text from public.profiles where id = auth.uid());
  v_limit   int;
  v_used    int;
begin
  if tg_op = 'UPDATE' then
    new.student_id := old.student_id;
    new.book_id := old.book_id;
    new.term := old.term;
    new.tenant_id := old.tenant_id;
    new.added_role := old.added_role;
    new.added_by := old.added_by;
    new.created_at := old.created_at;
    return new;
  end if;
  -- Aynı öğrenciye eşzamanlı eklemeler sınırı aşmasın.
  select * into v_student from public.profiles where id = new.student_id for update;
  if v_student.role is distinct from 'student' then
    raise exception 'BOOK_BAD_STUDENT';
  end if;
  if auth.uid() is not null and auth.uid() <> new.student_id
     and not public.can_manage_student(new.student_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if not exists (select 1 from public.books b
                 where b.id = new.book_id and b.status = 'active'
                   and b.org_id = v_student.org_id) then
    raise exception 'BOOK_NOT_IN_POOL';
  end if;
  new.term := public.current_term();
  new.tenant_id := v_student.tenant_id;
  new.added_by := auth.uid();
  new.added_role := coalesce(v_role, 'system');
  new.created_at := now();
  if auth.uid() = new.student_id then
    new.status := 'active';
    new.started_on := (now() at time zone 'Europe/Istanbul')::date;
  end if;
  v_limit := coalesce(
    (select book_limit from public.student_book_limits
     where student_id = new.student_id and term = new.term), 7);
  select count(*) into v_used from public.student_books
  where student_id = new.student_id and term = new.term;
  if v_used >= v_limit then
    raise exception 'BOOK_LIMIT';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_student_book() from public, anon, authenticated;
create trigger guard_student_book before insert or update on public.student_books
  for each row execute function public.guard_student_book();

create or replace function public.guard_book_progress()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_sb public.student_books%rowtype;
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
begin
  -- mirror_book_progress'in question_log_id yazması (iç güncelleme).
  if pg_trigger_depth() > 1 then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    new.student_book_id := old.student_book_id;
    new.student_id := old.student_id;
    new.tenant_id := old.tenant_id;
    new.created_by := old.created_by;
    new.entered_role := old.entered_role;
    new.created_at := old.created_at;
    new.question_log_id := old.question_log_id;
  else
    select * into v_sb from public.student_books where id = new.student_book_id;
    if v_sb.id is null then
      raise exception 'BOOK_BAD_REF';
    end if;
    if auth.uid() is not null and auth.uid() <> v_sb.student_id
       and not public.can_manage_student(v_sb.student_id) then
      raise exception 'NOT_ALLOWED';
    end if;
    new.student_id := v_sb.student_id;
    new.tenant_id := v_sb.tenant_id;
    new.created_by := auth.uid();
    new.entered_role := coalesce((select role::text from public.profiles where id = auth.uid()), 'system');
    new.created_at := now();
    new.question_log_id := null;
  end if;
  if new.studied_on > v_today then
    raise exception 'BOOK_FUTURE_DATE';
  end if;
  if new.studied_on < v_today - 365 then
    raise exception 'BOOK_BAD_DATE';
  end if;
  new.topic_text := nullif(trim(new.topic_text), '');
  new.note := nullif(trim(new.note), '');
  return new;
end;
$$;
revoke all on function public.guard_book_progress() from public, anon, authenticated;
create trigger guard_book_progress before insert or update on public.book_progress
  for each row execute function public.guard_book_progress();

-- Çalışma kaydı → question_logs (doğru/yanlış/boş girildiyse; ders kitaptan
-- ya da seçilen konudan).
create or replace function public.mirror_book_progress()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_subject smallint;
  v_source  text;
  v_log     uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') and old.question_log_id is not null then
    delete from public.question_logs where id = old.question_log_id;
  end if;
  if tg_op = 'DELETE' then
    return null;
  end if;
  if coalesce(new.correct, 0) + coalesce(new.wrong, 0) + coalesce(new.blank, 0) = 0 then
    update public.book_progress set question_log_id = null
    where id = new.id and question_log_id is not null;
    return null;
  end if;
  select coalesce(b.subject_id, (select t.subject_id from public.topics t where t.id = new.topic_id)),
         b.name || ' (' || b.publisher || ')'
  into v_subject, v_source
  from public.student_books sb join public.books b on b.id = sb.book_id
  where sb.id = new.student_book_id;
  if v_subject is null then
    update public.book_progress set question_log_id = null
    where id = new.id and question_log_id is not null;
    return null;
  end if;
  insert into public.question_logs
    (student_id, subject_id, topic_id, correct, wrong, blank, logged_on, source)
  values (new.student_id, v_subject, new.topic_id, coalesce(new.correct, 0),
          coalesce(new.wrong, 0), coalesce(new.blank, 0), new.studied_on, left(v_source, 200))
  returning id into v_log;
  update public.book_progress set question_log_id = v_log where id = new.id;
  return null;
end;
$$;
revoke all on function public.mirror_book_progress() from public, anon, authenticated;
create trigger mirror_book_progress
  after insert or delete or update of correct, wrong, blank, topic_id, studied_on
  on public.book_progress
  for each row execute function public.mirror_book_progress();

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.books enable row level security;
create policy "org reads books" on public.books
  for select to authenticated
  using (org_id = (select public.my_org())
         and (status = 'active'
              or requested_by = (select auth.uid())
              or (select public.my_role()) in ('coach', 'admin')));
create policy "org members add books" on public.books
  for insert to authenticated
  with check (org_id = (select public.my_org())
              and (select public.my_role()) in ('student', 'coach', 'admin'));
create policy "managers edit books" on public.books
  for update to authenticated
  using (org_id = (select public.my_org()) and (select public.my_role()) in ('coach', 'admin'))
  with check (org_id = (select public.my_org()) and (select public.my_role()) in ('coach', 'admin'));
create policy "managers delete books" on public.books
  for delete to authenticated
  using (org_id = (select public.my_org()) and (select public.my_role()) in ('coach', 'admin'));

alter table public.student_books enable row level security;
create policy "view student books" on public.student_books
  for select to authenticated using ((select public.can_view_student(student_id)));
create policy "add student books" on public.student_books
  for insert to authenticated
  with check (student_id = (select auth.uid())
              or (select public.can_manage_student(student_id)));
create policy "managers edit student books" on public.student_books
  for update to authenticated
  using ((select public.can_manage_student(student_id)))
  with check ((select public.can_manage_student(student_id)));
create policy "managers delete student books" on public.student_books
  for delete to authenticated using ((select public.can_manage_student(student_id)));

alter table public.student_book_limits enable row level security;
create policy "view book limits" on public.student_book_limits
  for select to authenticated using ((select public.can_view_student(student_id)));

alter table public.book_progress enable row level security;
create policy "view book progress" on public.book_progress
  for select to authenticated using ((select public.can_view_student(student_id)));
create policy "add book progress" on public.book_progress
  for insert to authenticated
  with check (student_id = (select auth.uid())
              or (select public.can_manage_student(student_id)));
create policy "edit book progress" on public.book_progress
  for update to authenticated
  using ((created_by = (select auth.uid()) and student_id = (select auth.uid())
          and created_at > now() - interval '24 hours')
         or (select public.can_manage_student(student_id)))
  with check ((created_by = (select auth.uid()) and student_id = (select auth.uid()))
              or (select public.can_manage_student(student_id)));
create policy "delete book progress" on public.book_progress
  for delete to authenticated
  using ((created_by = (select auth.uid()) and student_id = (select auth.uid())
          and created_at > now() - interval '24 hours')
         or (select public.can_manage_student(student_id)));

do $$
declare
  t text;
begin
  foreach t in array array['books', 'student_books', 'student_book_limits', 'book_progress'] loop
    execute format('create policy "tenant isolation" on public.%I as restrictive for all to public
                    using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
                    with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke truncate, trigger, references on public.%I from authenticated', t);
  end loop;
end;
$$;
revoke insert, update, delete on public.student_book_limits from authenticated;
-- Kurum ve talep alanlarını yalnızca sunucu yazar.
revoke update on public.books from authenticated;
grant update (name, publisher, subject_id, kind, status) on public.books to authenticated;
revoke update on public.student_books from authenticated;
grant update (status, started_on) on public.student_books to authenticated;

-- ---------------------------------------------------------------------
-- RPC'ler
-- ---------------------------------------------------------------------
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest', 'installment_due',
                  'timetable', 'book_request'));

create or replace function public.is_book_manager(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and org_id = p_org and role in ('coach', 'admin'))
$$;
revoke all on function public.is_book_manager(uuid) from public, anon, authenticated;

-- Talebi onayla: havuza girer, öğrenciye bildirim.
create or replace function public.approve_book(p_book uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  b public.books%rowtype;
begin
  select * into b from public.books where id = p_book for update;
  if b.id is null or not public.is_book_manager(b.org_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  update public.books set status = 'active' where id = p_book;
  if b.requested_by is not null and b.status = 'pending' then
    insert into public.notifications (user_id, kind, data, ref_id)
    values (b.requested_by, 'book_request',
            jsonb_build_object('result', 'approved', 'book', b.name,
                               'publisher', b.publisher, 'route', '/student/books'),
            p_book);
  end if;
end;
$$;
revoke all on function public.approve_book(uuid) from public, anon;
grant execute on function public.approve_book(uuid) to authenticated;

-- Talep zaten havuzdaki bir kitapsa: talep silinir, öğrenciye o kitap söylenir.
create or replace function public.merge_book_request(p_request uuid, p_into uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  r public.books%rowtype;
  t public.books%rowtype;
begin
  select * into r from public.books where id = p_request;
  select * into t from public.books where id = p_into;
  if r.id is null or t.id is null or r.org_id <> t.org_id or r.status <> 'pending'
     or t.status <> 'active' or not public.is_book_manager(r.org_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  delete from public.books where id = p_request;
  if r.requested_by is not null then
    insert into public.notifications (user_id, kind, data, ref_id)
    values (r.requested_by, 'book_request',
            jsonb_build_object('result', 'approved', 'book', t.name,
                               'publisher', t.publisher, 'route', '/student/books'),
            p_into);
  end if;
end;
$$;
revoke all on function public.merge_book_request(uuid, uuid) from public, anon;
grant execute on function public.merge_book_request(uuid, uuid) to authenticated;

create or replace function public.reject_book_request(p_request uuid, p_reason text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  r public.books%rowtype;
begin
  select * into r from public.books where id = p_request;
  if r.id is null or r.status <> 'pending' or not public.is_book_manager(r.org_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  delete from public.books where id = p_request;
  if r.requested_by is not null then
    insert into public.notifications (user_id, kind, data, ref_id)
    values (r.requested_by, 'book_request',
            jsonb_build_object('result', 'rejected', 'book', r.name,
                               'publisher', r.publisher,
                               'reason', left(nullif(trim(p_reason), ''), 200),
                               'route', '/student/books'),
            null);
  end if;
end;
$$;
revoke all on function public.reject_book_request(uuid, text) from public, anon;
grant execute on function public.reject_book_request(uuid, text) to authenticated;

-- Dönem sınırı (yalnızca koç / müdür).
create or replace function public.set_book_limit(p_student uuid, p_limit int, p_reason text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  if p_limit < 1 or p_limit > 50 then
    raise exception 'BAD_LIMIT';
  end if;
  insert into public.student_book_limits (student_id, term, tenant_id, book_limit, reason, changed_by)
  select p_student, public.current_term(), p.tenant_id, p_limit,
         left(nullif(trim(p_reason), ''), 300), auth.uid()
  from public.profiles p where p.id = p_student
  on conflict (student_id, term) do update
    set book_limit = excluded.book_limit, reason = excluded.reason,
        changed_by = excluded.changed_by, changed_at = now();
end;
$$;
revoke all on function public.set_book_limit(uuid, int, text) from public, anon;
grant execute on function public.set_book_limit(uuid, int, text) to authenticated;

-- Öğrencinin kitap hakkı ve kitapları (öğrenci, koç, müdür, veli).
create or replace function public.student_books_overview(p_student uuid, p_term text default null)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_term text := coalesce(p_term, public.current_term());
begin
  if not public.can_view_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  return jsonb_build_object(
    'term', v_term,
    'current_term', public.current_term(),
    'limit', coalesce((select book_limit from public.student_book_limits
                       where student_id = p_student and term = v_term), 7),
    'used', (select count(*) from public.student_books
             where student_id = p_student and term = v_term),
    'terms', coalesce((select jsonb_agg(distinct term) from public.student_books
                       where student_id = p_student), '[]'::jsonb),
    'books', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', sb.id, 'book_id', b.id, 'name', b.name, 'publisher', b.publisher,
        'subject_id', b.subject_id, 'kind', b.kind, 'status', sb.status,
        'started_on', sb.started_on, 'added_role', sb.added_role,
        'questions', coalesce(p.q, 0), 'correct', coalesce(p.c, 0),
        'wrong', coalesce(p.w, 0), 'blank', coalesce(p.b, 0),
        'last_studied', p.last_on, 'entries', coalesce(p.n, 0))
        order by sb.created_at)
      from public.student_books sb
      join public.books b on b.id = sb.book_id
      left join lateral (
        select sum(coalesce(bp.questions, coalesce(bp.correct, 0) + coalesce(bp.wrong, 0) + coalesce(bp.blank, 0))) q,
               sum(bp.correct) c, sum(bp.wrong) w, sum(bp.blank) b,
               max(bp.studied_on) last_on, count(*) n
        from public.book_progress bp where bp.student_book_id = sb.id) p on true
      where sb.student_id = p_student and sb.term = v_term), '[]'::jsonb));
end;
$$;
revoke all on function public.student_books_overview(uuid, text) from public, anon;
grant execute on function public.student_books_overview(uuid, text) to authenticated;

-- Havuz kullanımı ve sınıf geneli: kitap → öğrenci sayısı, ortalama soru
-- (koç: kendi öğrencileri, müdür: kurum; isteğe bağlı sınıf süzgeci).
create or replace function public.book_usage(p_classroom uuid default null)
returns table (book_id uuid, students int, avg_questions numeric, total_questions int)
language sql stable security definer set search_path = ''
as $$
  with mine as (
    select m.id from public.my_managed_students() m(id)
    where p_classroom is null or exists (
      select 1 from public.classroom_students cs
      where cs.student_id = m.id and cs.classroom_id = p_classroom)
  ), per as (
    select sb.book_id, sb.student_id,
           coalesce(sum(coalesce(bp.questions, coalesce(bp.correct, 0) + coalesce(bp.wrong, 0) + coalesce(bp.blank, 0))), 0) q
    from public.student_books sb
    join mine on mine.id = sb.student_id
    left join public.book_progress bp on bp.student_book_id = sb.id
    group by sb.book_id, sb.student_id
  )
  select book_id, count(*)::int, round(avg(q), 1), sum(q)::int
  from per group by book_id
$$;
revoke all on function public.book_usage(uuid) from public, anon;
grant execute on function public.book_usage(uuid) to authenticated;

-- Denemede başarısı düşük (≥ 3 soru, < %50) ama son 60 günde kitapla ya da
-- soru kaydıyla çalışılmamış konular.
create or replace function public.topic_gaps(p_student uuid)
returns table (topic_id int, topic_name text, subject_id smallint,
               answered int, correct int, rate int)
language sql stable security definer set search_path = ''
as $$
  select t.id, t.name, t.subject_id, x.answered, x.correct,
         round(100.0 * x.correct / x.answered)::int
  from (
    select a.topic_id, count(*) filter (where a.marked is not null)::int answered,
           count(*) filter (where a.marked = a.correct)::int correct
    from public.exam_answers a
    join public.exams e on e.id = a.exam_id
    where e.student_id = p_student and a.topic_id is not null
      and e.taken_on > current_date - 120
    group by a.topic_id
  ) x
  join public.topics t on t.id = x.topic_id
  where public.can_view_student(p_student)
    and x.answered >= 3 and x.correct * 2 < x.answered
    and not exists (select 1 from public.book_progress bp
                    where bp.student_id = p_student and bp.topic_id = x.topic_id
                      and bp.studied_on > current_date - 60)
    and not exists (select 1 from public.question_logs q
                    where q.student_id = p_student and q.topic_id = x.topic_id
                      and q.logged_on > current_date - 60)
  order by x.correct::numeric / x.answered, x.answered desc
  limit 10
$$;
revoke all on function public.topic_gaps(uuid) from public, anon;
grant execute on function public.topic_gaps(uuid) to authenticated;

-- Havuzu Excel'den doldur (müdür/koç): [{name, publisher, subject_id, kind}].
-- Aynı ad + yayın varsa atlanır. Döner: {inserted, skipped}.
create or replace function public.import_books(p_rows jsonb)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.profiles
                 where id = auth.uid() and role in ('coach', 'admin'));
  r jsonb;
  v_ins int := 0;
  v_skip int := 0;
begin
  if v_org is null then
    raise exception 'NOT_ALLOWED';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 3000 then
    raise exception 'BAD_INPUT';
  end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    insert into public.books (org_id, name, publisher, subject_id, kind, status)
    values (v_org, r ->> 'name', r ->> 'publisher', nullif(r ->> 'subject_id', '')::smallint,
            coalesce(nullif(r ->> 'kind', ''), 'question_bank'), 'active')
    on conflict (org_id, name_key, publisher_key) do nothing;
    if found then v_ins := v_ins + 1; else v_skip := v_skip + 1; end if;
  end loop;
  return jsonb_build_object('inserted', v_ins, 'skipped', v_skip);
end;
$$;
revoke all on function public.import_books(jsonb) from public, anon;
grant execute on function public.import_books(jsonb) to authenticated;
