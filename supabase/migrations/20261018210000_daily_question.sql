-- =====================================================================
-- Günün Sorusu
-- ---------------------------------------------------------------------
--  * Her öğrenciye her gün tek bir soru: ders güne göre döner, soru
--    öğrenci + güne göre seçilir (daily_question_id; havuz uygulamada,
--    assets/learn/questions, kimlikler ders-0001..). Günlük çalışma hakkını
--    harcamaz.
--  * daily_answers: günde bir cevap; yalnızca o günün sorusu kabul edilir.
--  * Seri: art arda doğru cevaplanan günler (my_daily_question).
--  * Her sabah 09:00'da (TR) henüz cevaplamayan öğrencilere bildirim
--    ('daily_question').
--
-- Geri almak için: supabase/rollbacks/20261018210000_daily_question.down.sql
-- =====================================================================

create or replace function public.daily_question_id(p_student uuid, p_day date)
returns text
language plpgsql immutable set search_path = ''
as $$
declare
  v_subjects text[] := array['TYT_TUR', 'TYT_MAT', 'TYT_FIZ', 'TYT_KIM', 'TYT_BIY',
                             'TYT_TAR', 'TYT_COG', 'TYT_FEL', 'TYT_DIN'];
  v_subject text;
  v_pool int;
  v_n int;
begin
  -- Ders her gün bir sonrakine geçer; öğrenciler farklı dersten başlar.
  v_subject := v_subjects[1 + mod((p_day - date '2026-01-01') + abs(hashtext(p_student::text)), 9)];
  v_pool := case when v_subject in ('TYT_TUR', 'TYT_MAT') then 600 else 300 end;
  v_n := 1 + mod(abs(hashtext(p_student::text || '/' || p_day::text)), v_pool);
  return v_subject || '-' || lpad(v_n::text, 4, '0');
end;
$$;

create table public.daily_answers (
  student_id  uuid not null references public.profiles (id) on delete cascade,
  tenant_id   uuid not null references public.tenants (id),
  answered_on date not null default (now() at time zone 'Europe/Istanbul')::date,
  question_id text not null,
  correct     boolean not null,
  created_at  timestamptz not null default now(),
  primary key (student_id, answered_on)
);
create index on public.daily_answers (tenant_id);

create or replace function public.guard_daily_answer()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.answered_on := (now() at time zone 'Europe/Istanbul')::date;
  new.created_at := now();
  if new.question_id is distinct from public.daily_question_id(new.student_id, new.answered_on) then
    raise exception 'NOT_TODAYS_QUESTION';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_daily_answer() from public, anon, authenticated;

create trigger set_tenant_id before insert on public.daily_answers
  for each row execute function public.set_tenant_id();
create trigger guard_daily_answer before insert on public.daily_answers
  for each row execute function public.guard_daily_answer();

alter table public.daily_answers enable row level security;
create policy "read daily answers" on public.daily_answers
  for select to authenticated
  using ((select public.can_view_student(student_id)));
create policy "student answers daily question" on public.daily_answers
  for insert to authenticated
  with check (student_id = (select auth.uid())
              and (select public.my_role()) = 'student');
create policy "tenant isolation" on public.daily_answers as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));
revoke all on public.daily_answers from anon;
revoke update, delete, truncate, trigger, references on public.daily_answers from authenticated;

-- Oturumdaki öğrencinin bugünkü sorusu, cevabı ve doğru serisi.
create or replace function public.my_daily_question()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_me    uuid := auth.uid();
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_ans   public.daily_answers%rowtype;
  v_day   date;
  v_streak int := 0;
begin
  if v_me is null or public.my_role() is distinct from 'student' then
    return null;
  end if;
  select * into v_ans from public.daily_answers where student_id = v_me and answered_on = v_today;
  -- Seri bugünden (cevaplandıysa) ya da dünden geriye sayılır.
  v_day := case when found then v_today else v_today - 1 end;
  loop
    exit when not exists (
      select 1 from public.daily_answers
      where student_id = v_me and answered_on = v_day and correct);
    v_streak := v_streak + 1;
    v_day := v_day - 1;
  end loop;
  return jsonb_build_object(
    'question_id', public.daily_question_id(v_me, v_today),
    'answered', v_ans.student_id is not null,
    'correct', v_ans.correct,
    'streak', v_streak);
end;
$$;
revoke execute on function public.my_daily_question() from public, anon;
grant execute on function public.my_daily_question() to authenticated;

-- Bildirim türü
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question'));

create or replace function public.send_daily_questions(p_now timestamptz default now())
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_today date := (p_now at time zone 'Europe/Istanbul')::date;
  v_n int;
begin
  insert into public.notifications (user_id, kind, data)
  select p.id, 'daily_question',
         jsonb_build_object(
           'subject', split_part(public.daily_question_id(p.id, v_today), '-', 1),
           'route', '/student/daily')
  from public.profiles p
  join public.tenants t on t.id = p.tenant_id and t.is_active
  where p.role = 'student'
    and not exists (select 1 from public.daily_answers a
                    where a.student_id = p.id and a.answered_on = v_today)
    and not exists (select 1 from public.notifications n
                    where n.user_id = p.id and n.kind = 'daily_question'
                      and (n.created_at at time zone 'Europe/Istanbul')::date = v_today);
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.send_daily_questions(timestamptz) from public, anon, authenticated;

-- 06:00 UTC = 09:00 TR
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('daily-question', '0 6 * * *', 'select public.send_daily_questions()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); zamanlanmadı';
  end if;
end;
$$;
