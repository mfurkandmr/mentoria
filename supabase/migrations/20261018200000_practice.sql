-- =====================================================================
-- Eğitim: günlük soru çözme hakları
-- ---------------------------------------------------------------------
-- Soru havuzu uygulamada (assets/learn/questions, telifsiz, özgün); burada
-- yalnızca öğrencinin cevapları tutulur:
--  * Günlük hak (Türkiye günü): Türkçe ve Matematik 20, diğer TYT dersleri 10.
--    Sınır tetikleyicide; istemci aşamaz, telefon değiştirse de geçerli.
--  * Hangi soruların çözüldüğü buradan okunur; havuz bitene kadar aynı soru
--    tekrar gelmez.
--  * Öğrenci yazar; koçu, kurum müdürü ve velisi okur (can_view_student).
--
-- Geri almak için: supabase/rollbacks/20261018200000_practice.down.sql
-- =====================================================================

create table public.practice_answers (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants (id),
  student_id   uuid not null references public.profiles (id) on delete cascade,
  subject_code text not null check (subject_code in (
                 'TYT_TUR', 'TYT_MAT', 'TYT_FIZ', 'TYT_KIM', 'TYT_BIY',
                 'TYT_TAR', 'TYT_COG', 'TYT_FEL', 'TYT_DIN')),
  question_id  text not null check (question_id ~ '^TYT_[A-Z]{3}-[0-9]{4}$'),
  correct      boolean not null,
  answered_on  date not null default (now() at time zone 'Europe/Istanbul')::date,
  created_at   timestamptz not null default now(),
  check (split_part(question_id, '-', 1) = subject_code)
);
create index on public.practice_answers (student_id, subject_code, answered_on);
create index on public.practice_answers (tenant_id);

create or replace function public.practice_daily_limit(p_subject text)
returns int
language sql immutable set search_path = ''
as $$
  select case when p_subject in ('TYT_TUR', 'TYT_MAT') then 20 else 10 end
$$;

-- Günlük hakkı aşan cevap reddedilir; tarih istemciden alınmaz.
create or replace function public.guard_practice_answer()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_used int;
begin
  new.answered_on := (now() at time zone 'Europe/Istanbul')::date;
  new.created_at := now();
  perform pg_advisory_xact_lock(hashtext(new.student_id::text || new.subject_code));
  select count(*) into v_used from public.practice_answers
  where student_id = new.student_id and subject_code = new.subject_code
    and answered_on = new.answered_on;
  if v_used >= public.practice_daily_limit(new.subject_code) then
    raise exception 'DAILY_LIMIT';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_practice_answer() from public, anon, authenticated;

create trigger set_tenant_id before insert on public.practice_answers
  for each row execute function public.set_tenant_id();
create trigger guard_practice_answer before insert on public.practice_answers
  for each row execute function public.guard_practice_answer();

alter table public.practice_answers enable row level security;

create policy "read practice answers" on public.practice_answers
  for select to authenticated
  using ((select public.can_view_student(student_id)));
create policy "student answers practice" on public.practice_answers
  for insert to authenticated
  with check (student_id = (select auth.uid())
              and (select public.my_role()) = 'student');
create policy "tenant isolation" on public.practice_answers as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));

-- Cevaplar değiştirilmez / silinmez (hesap silinince cascade ile gider).
revoke all on public.practice_answers from anon;
revoke update, delete, truncate, trigger, references on public.practice_answers from authenticated;
