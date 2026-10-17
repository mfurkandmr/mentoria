-- =====================================================================
-- Haftalık çalışma planı ve deneme eğilimi (yükselen / düşen öğrenciler)
-- ---------------------------------------------------------------------
--  * plan_items: koç ya da kurum müdürü öğrencinin haftasına gün gün madde
--    (ders, konu, soru / dakika hedefi, not) ekler. Öğrenci yalnızca "yaptım"
--    işaretler (done_at). Koç, müdür ve veli okur.
--  * exam_trends(sınav türü): yönetilen öğrencilerin son 5 denemesinde ilk ve
--    son toplam net; ana sayfadaki "en çok yükselen / düşen 5" listesi için.
--
-- Geri almak için: supabase/rollbacks/20261018240000_plan_and_trends.down.sql
-- =====================================================================

create table public.plan_items (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references public.tenants (id),
  student_id     uuid not null references public.profiles (id) on delete cascade,
  created_by     uuid references public.profiles (id) on delete set null,
  day            date not null,
  subject_code   text not null check (subject_code ~ '^(TYT|AYT|YDT)_[A-Z0-9]{2,4}$'),
  topic          text check (length(topic) <= 120),
  question_count int check (question_count between 1 and 1000),
  minutes        int check (minutes between 5 and 600),
  note           text check (length(note) <= 300),
  done_at        timestamptz,
  created_at     timestamptz not null default now()
);
create index on public.plan_items (student_id, day);
create index on public.plan_items (tenant_id);
create index on public.plan_items (created_by);

create or replace function public.guard_plan_item()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if (select role from public.profiles where id = new.student_id) <> 'student' then
      raise exception 'PLAN_NOT_STUDENT';
    end if;
    new.created_by := auth.uid();
    new.created_at := now();
    new.done_at := null;
    if new.day < (now() at time zone 'Europe/Istanbul')::date - 7 then
      raise exception 'PLAN_DAY_PAST';
    end if;
    if (select count(*) from public.plan_items
        where student_id = new.student_id and day = new.day) >= 12 then
      raise exception 'PLAN_DAY_FULL';
    end if;
  else
    -- Yalnızca "yaptım" işareti değişebilir; zaman sunucudan.
    if (new.student_id, new.day, new.subject_code, new.topic, new.question_count,
        new.minutes, new.note, new.created_by, new.created_at, new.tenant_id)
       is distinct from
       (old.student_id, old.day, old.subject_code, old.topic, old.question_count,
        old.minutes, old.note, old.created_by, old.created_at, old.tenant_id) then
      raise exception 'PLAN_READ_ONLY';
    end if;
    new.done_at := case when new.done_at is null then null else coalesce(old.done_at, now()) end;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_plan_item() from public, anon, authenticated;

create trigger set_tenant_id before insert on public.plan_items
  for each row execute function public.set_tenant_id();
create trigger guard_plan_item before insert or update on public.plan_items
  for each row execute function public.guard_plan_item();

alter table public.plan_items enable row level security;
create policy "view plan" on public.plan_items
  for select to authenticated using ((select public.can_view_student(student_id)));
create policy "manager adds plan" on public.plan_items
  for insert to authenticated with check ((select public.can_manage_student(student_id)));
create policy "manager deletes plan" on public.plan_items
  for delete to authenticated using ((select public.can_manage_student(student_id)));
create policy "student or manager ticks plan" on public.plan_items
  for update to authenticated
  using (student_id = (select auth.uid()) or (select public.can_manage_student(student_id)))
  with check (student_id = (select auth.uid()) or (select public.can_manage_student(student_id)));
create policy "tenant isolation" on public.plan_items as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));
revoke all on public.plan_items from anon;
revoke update, truncate, trigger, references on public.plan_items from authenticated;
grant update (done_at) on public.plan_items to authenticated;

-- Son 5 denemede eğilim: ilk ve son toplam net (en az 2 deneme).
create or replace function public.exam_trends(p_exam_type text)
returns table (
  student_id  uuid,
  full_name   text,
  exam_count  int,
  first_net   numeric,
  last_net    numeric,
  delta       numeric,
  first_on    date,
  last_on     date
)
language sql stable security definer set search_path = ''
as $$
  with recent as (
    select e.student_id, e.taken_on,
           (select coalesce(sum(r.net), 0) from public.exam_subject_results r
            where r.exam_id = e.id) as net,
           row_number() over (partition by e.student_id
                              order by e.taken_on desc, e.created_at desc) as rn
    from public.exams e
    join public.profiles p on p.id = e.student_id
    where p.role = 'student'
      and e.exam_type::text = p_exam_type
      and public.my_tenant_active()
      and public.can_manage_student(e.student_id)
  ), last5 as (
    select * from recent where rn <= 5
  ), agg as (
    select l.student_id, count(*)::int as n,
           (array_agg(l.net order by l.rn desc))[1] as first_net,
           (array_agg(l.net order by l.rn))[1] as last_net,
           min(l.taken_on) as first_on, max(l.taken_on) as last_on
    from last5 l
    group by l.student_id
    having count(*) >= 2
  )
  select a.student_id, p.full_name, a.n, a.first_net, a.last_net,
         a.last_net - a.first_net, a.first_on, a.last_on
  from agg a
  join public.profiles p on p.id = a.student_id
  order by a.last_net - a.first_net desc
$$;
revoke execute on function public.exam_trends(text) from public, anon;
grant execute on function public.exam_trends(text) to authenticated;
