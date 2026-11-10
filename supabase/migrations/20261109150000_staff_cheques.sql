-- =====================================================================
-- Personel yönetimi ve çek / senet takibi (kurum müdürü)
-- ---------------------------------------------------------------------
--  * staff_members: çalışan kartı. Koça (profile_id) ya da öğretmene
--    (teacher_id) bağlanabilir; sekreter, temizlik gibi hesabı olmayan
--    personel bağsız tutulur. Kimlik numarası bilerek tutulmaz (KVKK).
--  * staff_leaves: izin kayıtları; aynı kişide tarih çakışması reddedilir.
--  * finance_expenses.staff_id / staff_name: personel ödemesi; kişi silinse
--    de kayıt adıyla kalır. Bir gider en çok bir kişiye bağlanır.
--  * finance_cheques: alınan ve verilen çek / senet. Yazma: ekleme ve (ilk
--    durumdayken) silme doğrudan, durum değişikliği set_cheque_status ile.
--    Tahsil edilen çek ücrete ya da gelire, ödenen çek gidere işlenir; geri
--    alınınca / karşılıksız çıkınca bu kayıt iptal edilir.
--  * Yetki: yalnızca kurum müdürü. Uygulama para hareketi yapmaz.
--
-- Geri almak için: supabase/rollbacks/20261109150000_staff_cheques.down.sql
-- =====================================================================

create table public.staff_members (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references public.tenants (id),
  org_id            uuid not null references public.organizations (id) on delete cascade,
  full_name         text not null check (length(trim(full_name)) between 1 and 80),
  job               text not null default 'other'
                    check (job in ('teacher', 'coach', 'assistant_manager', 'guidance',
                                   'secretary', 'accounting', 'cleaning', 'security', 'other')),
  employment        text not null default 'full' check (employment in ('full', 'part', 'hourly')),
  phone             text check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  email             text check (length(email) <= 120),
  start_on          date,
  end_on            date,
  monthly_salary    numeric(12, 2) not null default 0
                    check (monthly_salary >= 0 and monthly_salary <= 10000000),
  annual_leave_days smallint not null default 14 check (annual_leave_days between 0 and 60),
  emergency_name    text check (length(emergency_name) <= 80),
  emergency_phone   text check (emergency_phone ~ '^\+[1-9][0-9]{7,14}$'),
  note              text check (length(note) <= 500),
  profile_id        uuid unique references public.profiles (id) on delete set null,
  teacher_id        uuid unique references public.teachers (id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (end_on is null or start_on is null or end_on >= start_on)
);
create index on public.staff_members (org_id);
create index on public.staff_members (tenant_id);

create table public.staff_leaves (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references public.tenants (id),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  staff_id   uuid not null references public.staff_members (id) on delete cascade,
  kind       text not null default 'annual'
             check (kind in ('annual', 'sick', 'unpaid', 'excuse', 'other')),
  start_on   date not null,
  end_on     date not null,
  note       text check (length(note) <= 300),
  created_at timestamptz not null default now(),
  check (end_on >= start_on and end_on - start_on <= 366)
);
create index on public.staff_leaves (staff_id, start_on desc);
create index on public.staff_leaves (org_id);
create index on public.staff_leaves (tenant_id);

create or replace function public.guard_staff_member()
returns trigger
language plpgsql security definer set search_path = ''
as $$
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
  if new.profile_id is not null
     and (tg_op = 'INSERT' or new.profile_id is distinct from old.profile_id)
     and not exists (select 1 from public.profiles
                     where id = new.profile_id and org_id = new.org_id
                       and role in ('coach', 'admin')) then
    raise exception 'STAFF_BAD_REF';
  end if;
  if new.teacher_id is not null
     and (tg_op = 'INSERT' or new.teacher_id is distinct from old.teacher_id)
     and not exists (select 1 from public.teachers
                     where id = new.teacher_id and org_id = new.org_id) then
    raise exception 'STAFF_BAD_REF';
  end if;
  new.full_name := trim(new.full_name);
  new.email := nullif(trim(new.email), '');
  new.emergency_name := nullif(trim(new.emergency_name), '');
  new.note := nullif(trim(new.note), '');
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function public.guard_staff_member() from public, anon, authenticated;

create or replace function public.guard_staff_leave()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid;
begin
  if tg_op = 'UPDATE' then
    new.staff_id := old.staff_id;
  end if;
  select org_id into v_org from public.staff_members where id = new.staff_id;
  if v_org is null or not public.is_finance_admin(v_org) then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  new.org_id := v_org;
  new.tenant_id := (select tenant_id from public.organizations where id = v_org);
  new.note := nullif(trim(new.note), '');
  if exists (select 1 from public.staff_leaves l
             where l.staff_id = new.staff_id and l.id <> new.id
               and l.start_on <= new.end_on and l.end_on >= new.start_on) then
    raise exception 'STAFF_LEAVE_OVERLAP';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_staff_leave() from public, anon, authenticated;

create trigger guard_finance before insert or update on public.staff_members
  for each row execute function public.guard_staff_member();
create trigger guard_finance before insert or update on public.staff_leaves
  for each row execute function public.guard_staff_leave();

alter table public.finance_expenses
  add column staff_id   uuid references public.staff_members (id) on delete set null,
  add column staff_name text,
  drop constraint finance_expenses_one_payee,
  add constraint finance_expenses_one_payee
    check (num_nonnulls(coach_id, teacher_id, staff_id) <= 1);
create index on public.finance_expenses (staff_id);

-- guard_finance (org_id'yi yazar) sonrası çalışır; tetikleyiciler ada göre sıralı.
create or replace function public.guard_expense_staff()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.staff_id is not null then
    if tg_op = 'INSERT' or new.staff_id is distinct from old.staff_id then
      select full_name into new.staff_name from public.staff_members
      where id = new.staff_id and org_id = new.org_id;
      if new.staff_name is null then
        raise exception 'STAFF_BAD_REF';
      end if;
    else
      new.staff_name := old.staff_name;
    end if;
  elsif tg_op = 'INSERT' then
    new.staff_name := null;
  else
    -- Personel silindi (on delete set null): ad kayıtta kalır.
    new.staff_name := old.staff_name;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_expense_staff() from public, anon, authenticated;
create trigger guard_finance_zstaff before insert or update on public.finance_expenses
  for each row execute function public.guard_expense_staff();

-- ---------------------------------------------------------------------
-- Çek / senet
-- ---------------------------------------------------------------------
create table public.finance_cheques (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants (id),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  direction    text not null check (direction in ('received', 'given')),
  kind         text not null default 'cheque' check (kind in ('cheque', 'note')),
  serial_no    text check (length(serial_no) <= 40),
  bank         text check (length(bank) <= 80),
  party_name   text not null check (length(trim(party_name)) between 1 and 80),
  student_id   uuid references public.profiles (id) on delete set null,
  student_name text,
  fee_id       uuid references public.finance_fees (id) on delete set null,
  amount       numeric(12, 2) not null check (amount > 0 and amount <= 10000000),
  issue_on     date,
  due_on       date not null,
  status       text not null
               check (status in ('portfolio', 'deposited', 'collected', 'endorsed',
                                 'bounced', 'returned', 'issued', 'paid', 'cancelled')),
  status_on    date,
  account_id   uuid references public.finance_accounts (id) on delete set null,
  endorsed_to  text check (length(endorsed_to) <= 80),
  receipt_no   text,
  expense_id   uuid references public.finance_expenses (id) on delete set null,
  note         text check (length(note) <= 300),
  created_at   timestamptz not null default now()
);
create index on public.finance_cheques (org_id, due_on);
create index on public.finance_cheques (tenant_id);
create index on public.finance_cheques (student_id);
create index on public.finance_cheques (fee_id);
create index on public.finance_cheques (account_id);
create index on public.finance_cheques (expense_id);

-- Eklemede kurum, ad ve ilk durum sunucudan; durum yalnızca RPC ile değişir
-- (update politikası yok).
create or replace function public.guard_cheque_insert()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.org_id := (select org_id from public.profiles
                 where id = auth.uid() and role = 'admin');
  if new.org_id is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);
  new.student_name := null;
  if new.direction = 'given' then
    new.student_id := null;
    new.fee_id := null;
  end if;
  if new.student_id is not null then
    select full_name into new.student_name from public.profiles
    where id = new.student_id and role = 'student' and org_id = new.org_id;
    if new.student_name is null then
      raise exception 'FINANCE_BAD_STUDENT';
    end if;
  end if;
  if new.fee_id is not null then
    if not exists (select 1 from public.finance_fees f
                   where f.id = new.fee_id and f.org_id = new.org_id
                     and f.student_id is not distinct from new.student_id
                     and new.student_id is not null) then
      raise exception 'FINANCE_BAD_FEE';
    end if;
  end if;
  new.status := case when new.direction = 'received' then 'portfolio' else 'issued' end;
  new.status_on := null;
  new.account_id := null;
  new.endorsed_to := null;
  new.receipt_no := null;
  new.expense_id := null;
  new.party_name := trim(new.party_name);
  new.serial_no := nullif(trim(new.serial_no), '');
  new.bank := nullif(trim(new.bank), '');
  new.note := nullif(trim(new.note), '');
  new.created_at := now();
  return new;
end;
$$;
revoke all on function public.guard_cheque_insert() from public, anon, authenticated;
create trigger guard_finance before insert on public.finance_cheques
  for each row execute function public.guard_cheque_insert();

-- Yalnızca ilk durumdaki kayıt silinir; işlem görmüş kayıt tarihçede kalır.
create or replace function public.guard_cheque_delete()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.status not in ('portfolio', 'issued') and exists (
       select 1 from public.organizations where id = old.org_id) then
    raise exception 'CHEQUE_NOT_DELETABLE';
  end if;
  return old;
end;
$$;
revoke all on function public.guard_cheque_delete() from public, anon, authenticated;
create trigger guard_cheque_delete before delete on public.finance_cheques
  for each row execute function public.guard_cheque_delete();

create or replace function public.set_cheque_status(
  p_id uuid, p_status text, p_on date default null, p_account uuid default null,
  p_endorsed_to text default null)
returns public.finance_cheques
language plpgsql security definer set search_path = ''
as $$
declare
  c       public.finance_cheques%rowtype;
  v_on    date := coalesce(p_on, current_date);
  v_label text;
  v_exp   uuid;
  v_rcpt  text;
begin
  select * into c from public.finance_cheques where id = p_id for update;
  if not found or not public.is_finance_admin(c.org_id) then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  if not (case c.status
    when 'portfolio' then p_status in ('deposited', 'collected', 'endorsed', 'bounced', 'returned')
    when 'deposited' then p_status in ('collected', 'bounced', 'portfolio')
    when 'collected' then p_status in ('bounced', 'portfolio')
    when 'endorsed'  then p_status in ('bounced', 'portfolio')
    when 'returned'  then p_status = 'portfolio'
    when 'issued'    then p_status in ('paid', 'bounced', 'cancelled')
    when 'paid'      then p_status in ('bounced', 'issued')
    when 'cancelled' then p_status = 'issued'
    when 'bounced'   then p_status = case when c.direction = 'received'
                                          then 'portfolio' else 'issued' end
    else false end) then
    raise exception 'CHEQUE_BAD_STATUS';
  end if;
  perform public._finance_account_ok(c.org_id, p_account);
  v_label := concat_ws(' · ',
    case when c.kind = 'note' then 'Senet' else 'Çek' end, c.serial_no, c.party_name);

  -- Önceki durumun kaydını geri al: tahsilat makbuzu ya da gider.
  if c.status = 'collected' and c.receipt_no is not null
     and (exists (select 1 from public.finance_payments
                  where org_id = c.org_id and receipt_no = c.receipt_no and voided_at is null)
          or exists (select 1 from public.finance_incomes
                     where org_id = c.org_id and receipt_no = c.receipt_no and voided_at is null)) then
    perform public.void_receipt(c.receipt_no);
  end if;
  if c.status = 'paid' and c.expense_id is not null then
    delete from public.finance_expenses where id = c.expense_id;
  end if;

  -- Yeni durumun kaydı.
  if p_status = 'collected' then
    if c.fee_id is not null then
      v_rcpt := public.record_payment(c.fee_id, c.amount, v_on, 'other', p_account, v_label)
                  ->> 'receipt_no';
    else
      v_rcpt := public.record_income(v_on, 'other', c.amount, 'other', p_account,
                                     c.student_id, c.party_name, v_label);
    end if;
  elsif p_status = 'paid' then
    insert into public.finance_expenses (spent_on, category, amount, note, account_id)
    values (v_on, 'other', c.amount, v_label, p_account)
    returning id into v_exp;
  elsif p_status = 'endorsed' and nullif(trim(p_endorsed_to), '') is null then
    raise exception 'CHEQUE_NEEDS_ENDORSEE';
  end if;

  update public.finance_cheques
  set status = p_status,
      status_on = v_on,
      account_id = case when p_status in ('collected', 'paid', 'deposited') then p_account end,
      endorsed_to = case when p_status = 'endorsed' then trim(p_endorsed_to) end,
      receipt_no = v_rcpt,
      expense_id = v_exp
  where id = p_id
  returning * into c;
  return c;
end;
$$;
revoke all on function public.set_cheque_status(uuid, text, date, uuid, text) from public, anon;
grant execute on function public.set_cheque_status(uuid, text, date, uuid, text) to authenticated;

do $$
declare
  t text;
begin
  foreach t in array array['staff_members', 'staff_leaves', 'finance_cheques'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "tenant isolation" on public.%I as restrictive
                      for all to public
                      using (tenant_id = (select public.my_tenant())
                             and (select public.my_tenant_active()))
                      with check (tenant_id = (select public.my_tenant())
                                  and (select public.my_tenant_active()))', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke truncate, trigger, references on public.%I from authenticated', t);
  end loop;
  foreach t in array array['staff_members', 'staff_leaves'] loop
    execute format('create policy "finance admin" on public.%I
                      for all to authenticated
                      using ((select public.is_finance_admin(org_id)))
                      with check ((select public.is_finance_admin(org_id)))', t);
  end loop;
end $$;

-- Çek: okuma, ekleme, silme; güncelleme yalnızca set_cheque_status ile.
create policy "finance admin read" on public.finance_cheques for select to authenticated
  using ((select public.is_finance_admin(org_id)));
create policy "finance admin add" on public.finance_cheques for insert to authenticated
  with check ((select public.is_finance_admin(org_id)));
create policy "finance admin delete" on public.finance_cheques for delete to authenticated
  using ((select public.is_finance_admin(org_id)));
revoke update on public.finance_cheques from authenticated;
