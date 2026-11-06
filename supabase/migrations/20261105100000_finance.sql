-- =====================================================================
-- Kurum finansı (yalnızca kurum müdürü)
-- ---------------------------------------------------------------------
-- Kayıt defteri: uygulama ödeme almaz; ödeme elden / havaleyle yapılır,
-- müdür işaretler. Öğrenci, veli ve koç hiçbir satırı göremez.
--  * finance_fees: öğrenci başına ücret (ör. "2026-2027 YKS kursu", toplam).
--    Öğrenci hesabı silinse de kayıt kalır (mali kayıt; student_id null
--    olur, ad student_name'de durur).
--  * finance_installments: ücretin taksitleri (vade, tutar, ödendiği gün,
--    ödeme şekli). paid_on boşsa ödenmedi; vadesi geçmişse gecikmiş.
--  * finance_expenses: kurum giderleri (kira, maaş, prim, fatura, ...).
--    Maaş / prim satırı bir koça bağlanabilir (koç silinse de ad kalır).
--  * coach_pay_rates: koç başına aylık maaş ve öğrenci başına prim; uygulama
--    bu ayın önerilen ödemesini hesaplar, müdür gider olarak kaydeder.
--  * org_id ve tenant_id istemciden gelmez, guard_* tetikleyicileri yazar
--    (genel set_tenant_id student_id bekler, bu tablolarda yok).
--
-- Geri almak için: supabase/rollbacks/20261105100000_finance.down.sql
-- =====================================================================

create table public.finance_fees (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants (id),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  student_id   uuid references public.profiles (id) on delete set null,
  student_name text not null,
  title        text not null check (length(trim(title)) between 1 and 120),
  total        numeric(12, 2) not null check (total > 0 and total <= 10000000),
  note         text check (length(note) <= 500),
  created_at   timestamptz not null default now()
);
create index on public.finance_fees (org_id, created_at desc);
create index on public.finance_fees (student_id);
create index on public.finance_fees (tenant_id);

create table public.finance_installments (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references public.tenants (id),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  fee_id     uuid not null references public.finance_fees (id) on delete cascade,
  due_on     date not null,
  amount     numeric(12, 2) not null check (amount > 0 and amount <= 10000000),
  paid_on    date,
  method     text check (method in ('cash', 'transfer', 'card', 'other')),
  created_at timestamptz not null default now()
);
create index on public.finance_installments (fee_id, due_on);
create index on public.finance_installments (org_id, due_on);
create index on public.finance_installments (tenant_id);

create table public.finance_expenses (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references public.tenants (id),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  spent_on   date not null,
  category   text not null
             check (category in ('rent', 'salary', 'bonus', 'bills', 'materials',
                                 'marketing', 'tax', 'other')),
  amount     numeric(12, 2) not null check (amount > 0 and amount <= 10000000),
  note       text check (length(note) <= 300),
  coach_id   uuid references public.profiles (id) on delete set null,
  coach_name text,
  created_at timestamptz not null default now()
);
create index on public.finance_expenses (org_id, spent_on desc);
create index on public.finance_expenses (coach_id);
create index on public.finance_expenses (tenant_id);

create table public.coach_pay_rates (
  coach_id       uuid primary key references public.profiles (id) on delete cascade,
  tenant_id      uuid not null references public.tenants (id),
  org_id         uuid not null references public.organizations (id) on delete cascade,
  monthly_salary numeric(12, 2) not null default 0
                 check (monthly_salary >= 0 and monthly_salary <= 10000000),
  per_student    numeric(12, 2) not null default 0
                 check (per_student >= 0 and per_student <= 1000000),
  updated_at     timestamptz not null default now()
);
create index on public.coach_pay_rates (org_id);
create index on public.coach_pay_rates (tenant_id);

-- Müdürün kendi kurumu mu (RLS'de tek çağrı).
create or replace function public.is_finance_admin(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and p.org_id = p_org)
$$;
revoke all on function public.is_finance_admin(uuid) from public, anon;
grant execute on function public.is_finance_admin(uuid) to authenticated;

-- Kurum ve ad alanlarını sunucu yazar; kurum değiştirilemez.
create or replace function public.guard_finance_row()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid;
begin
  if tg_op = 'UPDATE' then
    new.org_id := old.org_id;
    new.created_at := old.created_at;
  else
    new.org_id := (select org_id from public.profiles
                   where id = auth.uid() and role = 'admin');
    new.created_at := now();
  end if;
  if new.org_id is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);

  if tg_table_name = 'finance_fees' then
    if tg_op = 'INSERT' then
      select full_name into new.student_name from public.profiles
      where id = new.student_id and role = 'student' and org_id = new.org_id;
      if new.student_name is null then
        raise exception 'FINANCE_BAD_STUDENT';
      end if;
    else
      -- Öğrenci değiştirilemez; yalnızca hesabı silinince (on delete set
      -- null) boşalır, ad kayıtta kalır.
      if new.student_id is not null then
        new.student_id := old.student_id;
      end if;
      new.student_name := old.student_name;
    end if;
    new.title := trim(new.title);
    new.note := nullif(trim(new.note), '');

  elsif tg_table_name = 'finance_installments' then
    if tg_op = 'UPDATE' then
      new.fee_id := old.fee_id;
    end if;
    select org_id into v_org from public.finance_fees where id = new.fee_id;
    if v_org is distinct from new.org_id then
      raise exception 'FINANCE_BAD_FEE';
    end if;
    if new.paid_on is null then
      new.method := null;
    end if;

  elsif tg_table_name = 'finance_expenses' then
    if new.coach_id is not null then
      if tg_op = 'INSERT' or new.coach_id is distinct from old.coach_id then
        select full_name into new.coach_name from public.profiles
        where id = new.coach_id and role = 'coach' and org_id = new.org_id;
        if new.coach_name is null then
          raise exception 'FINANCE_BAD_COACH';
        end if;
      else
        new.coach_name := old.coach_name;
      end if;
    elsif tg_op = 'INSERT' then
      new.coach_name := null;
    else
      -- Koç hesabı silindi (on delete set null): ad kayıtta kalır.
      new.coach_name := old.coach_name;
    end if;
    new.note := nullif(trim(new.note), '');
  end if;
  return new;
end;
$$;
revoke all on function public.guard_finance_row() from public, anon, authenticated;

create or replace function public.guard_coach_pay_rate()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.coach_id := old.coach_id;
    new.org_id := old.org_id;
  else
    new.org_id := (select org_id from public.profiles
                   where id = auth.uid() and role = 'admin');
    if not exists (select 1 from public.profiles
                   where id = new.coach_id and role = 'coach'
                     and org_id = new.org_id) then
      raise exception 'FINANCE_BAD_COACH';
    end if;
  end if;
  if new.org_id is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function public.guard_coach_pay_rate() from public, anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array['finance_fees', 'finance_installments',
                           'finance_expenses', 'coach_pay_rates'] loop
    execute format('create trigger guard_finance before insert or update on public.%I
                      for each row execute function public.%I()', t,
                   case when t = 'coach_pay_rates' then 'guard_coach_pay_rate'
                        else 'guard_finance_row' end);
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "finance admin" on public.%I
                      for all to authenticated
                      using ((select public.is_finance_admin(org_id)))
                      with check ((select public.is_finance_admin(org_id)))', t);
    execute format('create policy "tenant isolation" on public.%I as restrictive
                      for all to public
                      using (tenant_id = (select public.my_tenant())
                             and (select public.my_tenant_active()))
                      with check (tenant_id = (select public.my_tenant())
                                  and (select public.my_tenant_active()))', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke truncate, trigger, references on public.%I from authenticated', t);
  end loop;
end $$;
