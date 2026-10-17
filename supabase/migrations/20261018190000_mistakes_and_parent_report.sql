-- =====================================================================
-- Hata Defteri (aralıklı tekrar) ve velilere haftalık rapor
-- ---------------------------------------------------------------------
-- Hata Defteri:
--  * mistake_cards: öğrencinin yanlış yaptığı soru (fotoğraf + ders/konu +
--    not). Tekrar aralıkları 1 → 3 → 7 → 21 gün; dördüncü başarılı
--    tekrardan sonra "öğrenildi". Yanlış giderse başa döner.
--  * Öğrenci kendi kartlarını yönetir; koçu, kurum müdürü ve velisi okur
--    (can_view_student).
--  * Fotoğraflar özel "mistake-photos" kovasında, <öğrenci id>/... altında.
--    Yalnızca öğrenci yükler/siler; görebilenler can_view_student ile.
--  * Her sabah 10:00'da (TR) tekrarı gelen kartı olan öğrenciye tek bir
--    bildirim ('review').
-- Veli raporu:
--  * Her pazar 19:00'da (TR) her veliye, çocuğunun son 7 günü: soru,
--    odak dakikası, aktif gün ('weekly_report').
--
-- Geri almak için: supabase/rollbacks/20261018190000_mistakes_and_parent_report.down.sql
-- =====================================================================

create table public.mistake_cards (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references public.tenants (id),
  student_id       uuid not null references public.profiles (id) on delete cascade,
  subject_id       smallint not null references public.subjects (id),
  topic_id         int references public.topics (id) on delete set null,
  photo_path       text check (photo_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,80}$'),
  note             text check (char_length(note) <= 500),
  stage            smallint not null default 0 check (stage between 0 and 4),
  due_on           date not null default ((now() at time zone 'Europe/Istanbul')::date + 1),
  fails            smallint not null default 0 check (fails >= 0),
  last_reviewed_at timestamptz,
  mastered_at      timestamptz,
  created_at       timestamptz not null default now()
);
create index on public.mistake_cards (student_id, due_on) where mastered_at is null;
create index on public.mistake_cards (tenant_id);
create index on public.mistake_cards (subject_id);
create index on public.mistake_cards (topic_id);

create trigger set_tenant_id before insert or update on public.mistake_cards
  for each row execute function public.set_tenant_id();

alter table public.mistake_cards enable row level security;

create policy "read mistake cards" on public.mistake_cards
  for select to authenticated
  using ((select public.can_view_student(student_id)));
create policy "student adds mistake cards" on public.mistake_cards
  for insert to authenticated
  with check (student_id = (select auth.uid())
              and (select public.my_role()) = 'student');
create policy "student updates mistake cards" on public.mistake_cards
  for update to authenticated
  using (student_id = (select auth.uid()))
  with check (student_id = (select auth.uid()));
create policy "student deletes mistake cards" on public.mistake_cards
  for delete to authenticated
  using (student_id = (select auth.uid()));
create policy "tenant isolation" on public.mistake_cards as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));

revoke all on public.mistake_cards from anon;
revoke truncate, trigger, references on public.mistake_cards from authenticated;
-- Öğrenci yalnızca şunları değiştirir (kimlik, dershane, tarih değişmez).
revoke update on public.mistake_cards from authenticated;
grant update (subject_id, topic_id, note, photo_path, stage, due_on, fails,
              last_reviewed_at, mastered_at)
  on public.mistake_cards to authenticated;

-- Tekrar sonucu: çözdüyse bir sonraki aralık, çözemediyse başa döner.
-- Aralıklar sunucuda: 1, 3, 7, 21 gün.
create or replace function public.review_mistake(p_card uuid, p_solved boolean)
returns public.mistake_cards
language plpgsql security invoker set search_path = ''
as $$
declare
  v_card  public.mistake_cards%rowtype;
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_gaps  int[] := array[1, 3, 7, 21];
begin
  select * into v_card from public.mistake_cards
  where id = p_card and student_id = auth.uid() and mastered_at is null
  for update;
  if not found then
    raise exception 'CARD_NOT_FOUND';
  end if;

  if p_solved then
    if v_card.stage >= 3 then
      v_card.stage := 4;
      v_card.mastered_at := now();
    else
      v_card.stage := v_card.stage + 1;
      v_card.due_on := v_today + v_gaps[v_card.stage + 1];
    end if;
  else
    v_card.stage := 0;
    v_card.fails := v_card.fails + 1;
    v_card.due_on := v_today + 1;
  end if;

  update public.mistake_cards
  set stage = v_card.stage,
      due_on = v_card.due_on,
      fails = v_card.fails,
      mastered_at = v_card.mastered_at,
      last_reviewed_at = now()
  where id = p_card
  returning * into v_card;
  return v_card;
end;
$$;
revoke execute on function public.review_mistake(uuid, boolean) from public, anon;
grant  execute on function public.review_mistake(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------
-- Fotoğraf kovası (özel)
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'storage') then
    raise notice 'storage şeması yok, hata defteri kovası atlandı';
    return;
  end if;

  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('mistake-photos', 'mistake-photos', false, 2097152,
          array['image/jpeg', 'image/png', 'image/webp'])
  on conflict (id) do update
    set public = excluded.public,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

  execute $p$
    create policy "student uploads mistake photos" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'mistake-photos'
                  and (storage.foldername(name))[1] = (select auth.uid())::text
                  and (select public.my_role()) = 'student')
  $p$;
  execute $p$
    create policy "student deletes mistake photos" on storage.objects
      for delete to authenticated
      using (bucket_id = 'mistake-photos'
             and (storage.foldername(name))[1] = (select auth.uid())::text)
  $p$;
  execute $p$
    create policy "viewers read mistake photos" on storage.objects
      for select to authenticated
      using (bucket_id = 'mistake-photos'
             and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
             and (select public.can_view_student(((storage.foldername(name))[1])::uuid)))
  $p$;
end;
$$;

-- ---------------------------------------------------------------------
-- Bildirim türleri
-- ---------------------------------------------------------------------
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report'));

-- Tekrarı gelen kartı olan her öğrenciye günde tek bildirim.
create or replace function public.send_review_reminders(p_now timestamptz default now())
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_today date := (p_now at time zone 'Europe/Istanbul')::date;
  v_n int;
begin
  insert into public.notifications (user_id, kind, data)
  select c.student_id, 'review',
         jsonb_build_object('count', count(*), 'route', '/student/mistakes')
  from public.mistake_cards c
  join public.profiles p on p.id = c.student_id
  join public.tenants t on t.id = p.tenant_id and t.is_active
  where c.mastered_at is null
    and c.due_on <= v_today
    and not exists (
      select 1 from public.notifications n
      where n.user_id = c.student_id and n.kind = 'review'
        and (n.created_at at time zone 'Europe/Istanbul')::date = v_today)
  group by c.student_id;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.send_review_reminders(timestamptz) from public, anon, authenticated;

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

-- Zamanlayıcılar (UTC): 07:00 = 10:00 TR her gün; pazar 16:00 = 19:00 TR.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('review-reminders', '0 7 * * *',
                          'select public.send_review_reminders()');
    perform cron.schedule('parent-weekly-reports', '0 16 * * 0',
                          'select public.send_parent_weekly_reports()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); zamanlanmadı';
  end if;
end;
$$;
