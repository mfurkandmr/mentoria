-- =====================================================================
-- Öğretmen ödemeleri (kurum finansı)
-- ---------------------------------------------------------------------
-- Müdür her öğretmen için ödeme şeklini (saat başına / aylık sabit), tutarı
-- ve notunu kaydeder; yapılan ödeme gider olarak öğretmene bağlanır. Haftalık
-- ders saati yayındaki programdan (schedule_entries) uygulamada sayılır.
-- Uygulama para almaz ya da göndermez: kayıt defteridir.
--
--  * teacher_pay_rates: öğretmen başına tek satır. Öğretmen silinince gider.
--  * finance_expenses.teacher_id / teacher_name: öğretmen silinse de ödeme
--    kaydı adıyla kalır. Bir gider ya koça ya öğretmene bağlanır.
--  * Yetki: yalnızca kurum müdürü. org_id, tenant_id ve öğretmen adı sunucuda
--    yazılır; başka kurumun öğretmeni FINANCE_BAD_TEACHER ile reddedilir.
--
-- Geri almak için: supabase/rollbacks/20261109140000_teacher_pay.down.sql
-- =====================================================================

create table public.teacher_pay_rates (
  teacher_id uuid primary key references public.teachers (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  pay_type   text not null default 'hourly' check (pay_type in ('hourly', 'fixed')),
  amount     numeric(12, 2) not null default 0
             check (amount >= 0 and amount <= 10000000),
  note       text check (length(note) <= 300),
  updated_at timestamptz not null default now()
);
create index on public.teacher_pay_rates (org_id);
create index on public.teacher_pay_rates (tenant_id);

create or replace function public.guard_teacher_pay_rate()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.teacher_id := old.teacher_id;
    new.org_id := old.org_id;
  else
    new.org_id := (select org_id from public.profiles
                   where id = auth.uid() and role = 'admin');
  end if;
  if new.org_id is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  if not exists (select 1 from public.teachers
                 where id = new.teacher_id and org_id = new.org_id) then
    raise exception 'FINANCE_BAD_TEACHER';
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);
  new.note := nullif(trim(new.note), '');
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function public.guard_teacher_pay_rate() from public, anon, authenticated;

create trigger guard_finance before insert or update on public.teacher_pay_rates
  for each row execute function public.guard_teacher_pay_rate();

alter table public.teacher_pay_rates enable row level security;
create policy "finance admin" on public.teacher_pay_rates
  for all to authenticated
  using ((select public.is_finance_admin(org_id)))
  with check ((select public.is_finance_admin(org_id)));
create policy "tenant isolation" on public.teacher_pay_rates as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));
revoke all on public.teacher_pay_rates from anon;
revoke truncate, trigger, references on public.teacher_pay_rates from authenticated;

alter table public.finance_expenses
  add column teacher_id   uuid references public.teachers (id) on delete set null,
  add column teacher_name text,
  add constraint finance_expenses_one_payee
    check (coach_id is null or teacher_id is null);
create index on public.finance_expenses (teacher_id);

-- guard_finance (org_id'yi yazar) sonrası çalışması için ad "z" ile başlar;
-- tetikleyiciler ada göre sırayla çalışır.
create or replace function public.guard_expense_teacher()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.teacher_id is not null then
    if tg_op = 'INSERT' or new.teacher_id is distinct from old.teacher_id then
      select full_name into new.teacher_name from public.teachers
      where id = new.teacher_id and org_id = new.org_id;
      if new.teacher_name is null then
        raise exception 'FINANCE_BAD_TEACHER';
      end if;
    else
      new.teacher_name := old.teacher_name;
    end if;
  elsif tg_op = 'INSERT' then
    new.teacher_name := null;
  else
    -- Öğretmen silindi (on delete set null): ad kayıtta kalır.
    new.teacher_name := old.teacher_name;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_expense_teacher() from public, anon, authenticated;

create trigger guard_finance_zteacher before insert or update on public.finance_expenses
  for each row execute function public.guard_expense_teacher();
