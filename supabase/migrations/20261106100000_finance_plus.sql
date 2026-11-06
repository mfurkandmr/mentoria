-- =====================================================================
-- Kurum finansı: hesaplar, indirim, kısmi ödeme + makbuz, iade, diğer
-- gelirler, toplu ücret, veli görünümü
-- ---------------------------------------------------------------------
--  * finance_accounts: kasa / banka / POS hesapları (açılış bakiyesi);
--    tahsilat, gelir, gider ve hesaplar arası virman bir hesaba bağlanır.
--  * finance_discounts: ücrete indirim / burs / kardeş indirimi. Ücretin
--    total'i liste fiyatıdır; taksitlerin toplamı total − indirimler.
--    Sonradan eklenen indirim ödenmemiş taksitlerden, son vadeliden
--    başlayarak düşülür.
--  * finance_payments: tahsilat ve iade satırları. Bir tahsilat birden çok
--    taksite dağıtılabilir (aynı makbuz no). Taksidin ödenen tutarı
--    (paid_amount) ve ödendi günü (paid_on, tamamı ödenince) bu tablodan
--    tetikleyiciyle hesaplanır; istemci doğrudan yazamaz. Makbuz iptal
--    edilir (voided_at), silinmez; numara sırası bozulmaz.
--  * Makbuz no: kurum + yıl başına sıralı ("2026-000001").
--  * İade / kayıt iptali: cancel_fee; ödenmemiş taksitler silinir, kısmen
--    ödenen taksit ödenen tutara iner, iade satırı yazılır.
--  * finance_incomes: ücret dışı gelirler (kitap, özel ders, materyal,
--    etkinlik, diğer), makbuz no'lu.
--  * fee_plans: program / sınıf ücret şablonu; create_fees_bulk ile seçilen
--    öğrencilere tek seferde ücret açılır (veli telefonu yoklama kaydından).
--  * my_child_finance: veli çocuğunun ücretini, taksitlerini ve
--    makbuzlarını görür (yalnızca okuma).
--  * Ödemesi olan ücret silinemez (iptal edilir).
--
-- Geri almak için: supabase/rollbacks/20261106100000_finance_plus.down.sql
-- =====================================================================

create table public.finance_accounts (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references public.tenants (id),
  org_id          uuid not null references public.organizations (id) on delete cascade,
  name            text not null check (length(trim(name)) between 1 and 60),
  kind            text not null default 'cash' check (kind in ('cash', 'bank', 'pos')),
  iban            text check (iban is null or iban ~ '^TR[0-9]{24}$'),
  opening_balance numeric(12, 2) not null default 0
                  check (opening_balance between -10000000 and 10000000),
  archived        boolean not null default false,
  created_at      timestamptz not null default now()
);
create unique index finance_accounts_name on public.finance_accounts (org_id, public.norm_key(name));
create index on public.finance_accounts (tenant_id);

alter table public.finance_fees
  add column status       text not null default 'active' check (status in ('active', 'cancelled')),
  add column cancelled_on date,
  add column cancel_note  text check (length(cancel_note) <= 300);

alter table public.finance_installments
  add column paid_amount numeric(12, 2) not null default 0 check (paid_amount >= 0);

alter table public.finance_expenses
  add column account_id uuid references public.finance_accounts (id) on delete set null;
create index on public.finance_expenses (account_id);

create table public.finance_discounts (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references public.tenants (id),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  fee_id     uuid not null references public.finance_fees (id) on delete cascade,
  kind       text not null check (kind in ('discount', 'scholarship', 'sibling', 'other')),
  amount     numeric(12, 2) not null check (amount > 0 and amount <= 10000000),
  note       text check (length(note) <= 200),
  created_at timestamptz not null default now()
);
create index on public.finance_discounts (fee_id);
create index on public.finance_discounts (org_id);
create index on public.finance_discounts (tenant_id);

create table public.finance_payments (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references public.tenants (id),
  org_id         uuid not null references public.organizations (id) on delete cascade,
  fee_id         uuid not null references public.finance_fees (id) on delete cascade,
  installment_id uuid references public.finance_installments (id) on delete set null,
  kind           text not null default 'payment' check (kind in ('payment', 'refund')),
  amount         numeric(12, 2) not null check (amount > 0 and amount <= 10000000),
  paid_on        date not null,
  method         text check (method in ('cash', 'transfer', 'card', 'other')),
  account_id     uuid references public.finance_accounts (id) on delete set null,
  receipt_no     text,
  note           text check (length(note) <= 300),
  voided_at      timestamptz,
  created_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now()
);
create index on public.finance_payments (fee_id);
create index on public.finance_payments (installment_id);
create index on public.finance_payments (org_id, paid_on);
create index on public.finance_payments (org_id, receipt_no);
create index on public.finance_payments (account_id);
create index on public.finance_payments (tenant_id);
create index on public.finance_payments (created_by);

create table public.finance_incomes (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants (id),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  received_on  date not null,
  category     text not null
               check (category in ('books', 'private_lesson', 'material', 'event', 'other')),
  amount       numeric(12, 2) not null check (amount > 0 and amount <= 10000000),
  method       text check (method in ('cash', 'transfer', 'card', 'other')),
  account_id   uuid references public.finance_accounts (id) on delete set null,
  student_id   uuid references public.profiles (id) on delete set null,
  student_name text,
  payer_name   text check (length(payer_name) <= 80),
  note         text check (length(note) <= 300),
  receipt_no   text,
  voided_at    timestamptz,
  created_at   timestamptz not null default now()
);
create index on public.finance_incomes (org_id, received_on);
create index on public.finance_incomes (account_id);
create index on public.finance_incomes (student_id);
create index on public.finance_incomes (tenant_id);

create table public.finance_transfers (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants (id),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  from_account uuid not null references public.finance_accounts (id) on delete cascade,
  to_account   uuid not null references public.finance_accounts (id) on delete cascade,
  amount       numeric(12, 2) not null check (amount > 0 and amount <= 10000000),
  moved_on     date not null,
  note         text check (length(note) <= 200),
  created_at   timestamptz not null default now(),
  check (from_account <> to_account)
);
create index on public.finance_transfers (org_id, moved_on);
create index on public.finance_transfers (from_account);
create index on public.finance_transfers (to_account);
create index on public.finance_transfers (tenant_id);

create table public.fee_plans (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references public.tenants (id),
  org_id            uuid not null references public.organizations (id) on delete cascade,
  name              text not null check (length(trim(name)) between 1 and 120),
  total             numeric(12, 2) not null check (total > 0 and total <= 10000000),
  installment_count smallint not null default 1 check (installment_count between 1 and 24),
  note              text check (length(note) <= 300),
  created_at        timestamptz not null default now()
);
create unique index fee_plans_name on public.fee_plans (org_id, public.norm_key(name));
create index on public.fee_plans (tenant_id);

-- Makbuz sayacı (kurum + yıl); yalnızca fonksiyonlar yazar.
create table public.finance_receipt_seq (
  org_id  uuid not null references public.organizations (id) on delete cascade,
  year    smallint not null,
  last_no int not null default 0,
  primary key (org_id, year)
);
alter table public.finance_receipt_seq enable row level security;
revoke all on public.finance_receipt_seq from anon, authenticated;

-- Kurum ve tenant'ı sunucu yazar; bağlı hesap / öğrenci aynı kurumdan olmalı.
create or replace function public.guard_finance_extra()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.org_id := old.org_id;
    new.created_at := old.created_at;
  elsif coalesce(current_setting('mentoria.finance_sync', true), '') <> 'on' then
    new.org_id := (select org_id from public.profiles
                   where id = auth.uid() and role = 'admin');
    new.created_at := now();
  end if;
  if new.org_id is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);
  if tg_table_name = 'finance_accounts' then
    new.name := trim(new.name);
    new.iban := nullif(upper(replace(new.iban, ' ', '')), '');
  elsif tg_table_name = 'fee_plans' then
    new.name := trim(new.name);
  elsif tg_table_name = 'finance_transfers' then
    if (select count(*) from public.finance_accounts
        where id in (new.from_account, new.to_account) and org_id = new.org_id) <> 2 then
      raise exception 'FINANCE_BAD_ACCOUNT';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_finance_extra() from public, anon, authenticated;

-- Hesap aynı kurumdan mı (giderler için).
create or replace function public.guard_expense_account()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.account_id is not null and not exists (
       select 1 from public.finance_accounts
       where id = new.account_id and org_id = new.org_id) then
    raise exception 'FINANCE_BAD_ACCOUNT';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_expense_account() from public, anon, authenticated;
-- guard_finance'tan sonra çalışsın (org_id önce yazılır): ad sırası.
create trigger guard_finance_zaccount before insert or update on public.finance_expenses
  for each row execute function public.guard_expense_account();

-- Taksidin ödeme alanlarını yalnızca senkron yazar (mentoria.finance_sync).
create or replace function public.guard_installment_paid()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if coalesce(current_setting('mentoria.finance_sync', true), '') = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.paid_on := null; new.method := null; new.paid_amount := 0;
  else
    new.paid_on := old.paid_on; new.method := old.method;
    new.paid_amount := old.paid_amount;
    -- Kısmen ödenmiş taksidin tutarı ödenenin altına inemez.
    if new.amount < old.paid_amount then
      raise exception 'FINANCE_BELOW_PAID';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_installment_paid() from public, anon, authenticated;
create trigger guard_installment_paid before insert or update on public.finance_installments
  for each row execute function public.guard_installment_paid();

-- Taksidin ödenen tutarı / ödendi günü (iptal edilmemiş tahsilatlardan).
create or replace function public._sync_installment(p_installment uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_paid numeric;
  v_last record;
begin
  if p_installment is null then
    return;
  end if;
  perform set_config('mentoria.finance_sync', 'on', true);
  select coalesce(sum(amount), 0) into v_paid
  from public.finance_payments
  where installment_id = p_installment and kind = 'payment' and voided_at is null;
  select paid_on, method into v_last
  from public.finance_payments
  where installment_id = p_installment and kind = 'payment' and voided_at is null
  order by paid_on desc, created_at desc limit 1;
  update public.finance_installments
  set paid_amount = v_paid,
      paid_on = case when v_paid >= amount then v_last.paid_on end,
      method = case when v_paid >= amount then v_last.method end
  where id = p_installment;
  perform set_config('mentoria.finance_sync', 'off', true);
end;
$$;
revoke all on function public._sync_installment(uuid) from public, anon, authenticated;

create or replace function public.sync_installment_payment()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public._sync_installment(old.installment_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.installment_id is distinct from old.installment_id
     or tg_op = 'INSERT' then
    perform public._sync_installment(new.installment_id);
  end if;
  return null;
end;
$$;
revoke all on function public.sync_installment_payment() from public, anon, authenticated;
create trigger sync_installment_payment after insert or update or delete on public.finance_payments
  for each row execute function public.sync_installment_payment();

-- Ödemesi olan ücret doğrudan silinemez (kurum silinirken basamaklı silme geçer).
create or replace function public.guard_fee_delete()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if pg_trigger_depth() = 1 and exists (
       select 1 from public.finance_payments
       where fee_id = old.id and voided_at is null) then
    raise exception 'FINANCE_HAS_PAYMENTS';
  end if;
  return old;
end;
$$;
revoke all on function public.guard_fee_delete() from public, anon, authenticated;
create trigger guard_fee_delete before delete on public.finance_fees
  for each row execute function public.guard_fee_delete();

do $$
declare
  t text;
begin
  foreach t in array array['finance_accounts', 'finance_discounts', 'finance_payments',
                           'finance_incomes', 'finance_transfers', 'fee_plans'] loop
    if t in ('finance_accounts', 'finance_transfers', 'fee_plans') then
      execute format('create trigger guard_finance before insert or update on public.%I
                        for each row execute function public.guard_finance_extra()', t);
    end if;
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
-- Tahsilat, indirim ve gelir yalnızca fonksiyonlarla (makbuz no, taksit
-- senkronu); doğrudan yazma kapalı.
revoke insert, update, delete on public.finance_payments, public.finance_discounts,
  public.finance_incomes from authenticated;

-- Mevcut ödenmiş taksitler: tahsilat satırı (makbuzsuz, eski kayıt).
insert into public.finance_payments
  (tenant_id, org_id, fee_id, installment_id, amount, paid_on, method, note, created_at)
select tenant_id, org_id, fee_id, id, amount, paid_on, method, 'Önceki kayıt', created_at
from public.finance_installments where paid_on is not null;
do $$
begin
  perform set_config('mentoria.finance_sync', 'on', true);
  update public.finance_installments set paid_amount = amount where paid_on is not null;
end $$;

-- ---------------------------------------------------------------------
-- Fonksiyonlar
-- ---------------------------------------------------------------------
create or replace function public._next_receipt(p_org uuid, p_on date)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_year smallint := extract(year from coalesce(p_on, current_date))::smallint;
  v_no   int;
begin
  insert into public.finance_receipt_seq (org_id, year, last_no) values (p_org, v_year, 1)
  on conflict (org_id, year) do update set last_no = public.finance_receipt_seq.last_no + 1
  returning last_no into v_no;
  return v_year || '-' || lpad(v_no::text, 6, '0');
end;
$$;
revoke all on function public._next_receipt(uuid, date) from public, anon, authenticated;

create or replace function public._finance_account_ok(p_org uuid, p_account uuid)
returns void
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_account is not null and not exists (
       select 1 from public.finance_accounts where id = p_account and org_id = p_org) then
    raise exception 'FINANCE_BAD_ACCOUNT';
  end if;
end;
$$;
revoke all on function public._finance_account_ok(uuid, uuid) from public, anon, authenticated;

-- Ücret aç: liste fiyatı, indirimler, taksitler (toplamı fiyat − indirim).
-- p_discounts: [{"kind": "sibling", "amount": 1500, "note": "..."}]
-- p_installments: [{"due_on": "2026-12-05", "amount": 5000}]
create or replace function public.create_fee(
  p_student uuid, p_title text, p_total numeric, p_discounts jsonb,
  p_installments jsonb, p_note text, p_due_day int, p_payer_name text,
  p_payer_phone text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_org  uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  v_id   uuid;
  v_disc numeric;
  v_inst numeric;
begin
  if v_org is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  if jsonb_typeof(coalesce(p_installments, 'null')) <> 'array'
     or jsonb_array_length(p_installments) not between 1 and 36 then
    raise exception 'FINANCE_BAD_INSTALLMENTS';
  end if;
  select coalesce(sum((d->>'amount')::numeric), 0) into v_disc
  from jsonb_array_elements(coalesce(p_discounts, '[]'::jsonb)) d;
  select coalesce(sum((i->>'amount')::numeric), 0) into v_inst
  from jsonb_array_elements(p_installments) i;
  if v_disc < 0 or v_disc >= p_total or abs(v_inst - (p_total - v_disc)) > 0.01 then
    raise exception 'FINANCE_BAD_TOTAL';
  end if;

  insert into public.finance_fees
    (student_id, student_name, title, total, note, due_day, payer_name, payer_phone)
  values (p_student, '', p_title, p_total, p_note, p_due_day,
          nullif(trim(p_payer_name), ''), nullif(trim(p_payer_phone), ''))
  returning id into v_id;

  perform set_config('mentoria.finance_sync', 'on', true);
  insert into public.finance_discounts (tenant_id, org_id, fee_id, kind, amount, note)
  select f.tenant_id, f.org_id, v_id, d->>'kind', (d->>'amount')::numeric,
         nullif(trim(d->>'note'), '')
  from jsonb_array_elements(coalesce(p_discounts, '[]'::jsonb)) d
  cross join public.finance_fees f where f.id = v_id;
  perform set_config('mentoria.finance_sync', 'off', true);

  insert into public.finance_installments (fee_id, due_on, amount)
  select v_id, (i->>'due_on')::date, (i->>'amount')::numeric
  from jsonb_array_elements(p_installments) i;
  return v_id;
end;
$$;
revoke all on function public.create_fee(uuid, text, numeric, jsonb, jsonb, text, int, text, text) from public, anon;
grant execute on function public.create_fee(uuid, text, numeric, jsonb, jsonb, text, int, text, text) to authenticated;

-- Seçilen öğrencilere aynı ücret (program / sınıf). Aynı başlıkta aktif
-- ücreti olan öğrenci atlanır. Veli adı / telefonu yoklamadaki kayıttan.
-- Dönüş: {"created": n, "skipped": [student_id, ...]}
create or replace function public.create_fees_bulk(
  p_students uuid[], p_title text, p_total numeric, p_discounts jsonb,
  p_installments jsonb, p_note text, p_due_day int)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_org     uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  s         uuid;
  v_created int := 0;
  v_skipped uuid[] := '{}';
  g         record;
begin
  if v_org is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  if coalesce(cardinality(p_students), 0) not between 1 and 500 then
    raise exception 'FINANCE_BAD_STUDENTS';
  end if;
  foreach s in array p_students loop
    if not exists (select 1 from public.profiles
                   where id = s and role = 'student' and org_id = v_org)
       or exists (select 1 from public.finance_fees
                  where student_id = s and status = 'active'
                    and public.norm_key(title) = public.norm_key(p_title)) then
      v_skipped := v_skipped || s;
      continue;
    end if;
    select guardian_name, phone into g from public.student_guardian_phones where student_id = s;
    perform public.create_fee(s, p_title, p_total, p_discounts, p_installments, p_note,
                              p_due_day, g.guardian_name, g.phone);
    v_created := v_created + 1;
  end loop;
  return jsonb_build_object('created', v_created, 'skipped', to_jsonb(v_skipped));
end;
$$;
revoke all on function public.create_fees_bulk(uuid[], text, numeric, jsonb, jsonb, text, int) from public, anon;
grant execute on function public.create_fees_bulk(uuid[], text, numeric, jsonb, jsonb, text, int) to authenticated;

-- Tahsilat: tutar ödenmemiş taksitlere dağıtılır ([p_installment] önce,
-- sonra en eski vadeli). Kalan borçtan fazlası alınamaz. Tek makbuz no.
-- Dönüş: {"receipt_no", "allocated": [{"installment_id", "amount"}], "remaining"}
create or replace function public.record_payment(
  p_fee uuid, p_amount numeric, p_paid_on date, p_method text, p_account uuid,
  p_note text, p_installment uuid default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_fee     public.finance_fees%rowtype;
  v_left    numeric := round(p_amount, 2);
  v_open    numeric;
  v_receipt text;
  v_alloc   jsonb := '[]'::jsonb;
  r         record;
  v_part    numeric;
begin
  select * into v_fee from public.finance_fees where id = p_fee;
  if not found or not public.is_finance_admin(v_fee.org_id) then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  if v_fee.status <> 'active' then
    raise exception 'FINANCE_CANCELLED';
  end if;
  if v_left is null or v_left <= 0 then
    raise exception 'FINANCE_BAD_AMOUNT';
  end if;
  if p_method is not null and p_method not in ('cash', 'transfer', 'card', 'other') then
    raise exception 'FINANCE_BAD_METHOD';
  end if;
  perform public._finance_account_ok(v_fee.org_id, p_account);
  select coalesce(sum(amount - paid_amount), 0) into v_open
  from public.finance_installments where fee_id = p_fee;
  if v_left > v_open + 0.001 then
    raise exception 'FINANCE_OVERPAYMENT';
  end if;
  v_receipt := public._next_receipt(v_fee.org_id, coalesce(p_paid_on, current_date));
  for r in
    select id, amount - paid_amount open
    from public.finance_installments
    where fee_id = p_fee and amount > paid_amount
    order by (id = p_installment) desc, due_on, created_at
  loop
    exit when v_left <= 0;
    v_part := least(v_left, r.open);
    insert into public.finance_payments
      (tenant_id, org_id, fee_id, installment_id, kind, amount, paid_on, method,
       account_id, receipt_no, note, created_by)
    values (v_fee.tenant_id, v_fee.org_id, p_fee, r.id, 'payment', v_part,
            coalesce(p_paid_on, current_date), p_method, p_account, v_receipt,
            nullif(trim(p_note), ''), auth.uid());
    v_alloc := v_alloc || jsonb_build_object('installment_id', r.id, 'amount', v_part);
    v_left := v_left - v_part;
  end loop;
  return jsonb_build_object('receipt_no', v_receipt, 'allocated', v_alloc,
    'remaining', (select coalesce(sum(amount - paid_amount), 0)
                  from public.finance_installments where fee_id = p_fee));
end;
$$;
revoke all on function public.record_payment(uuid, numeric, date, text, uuid, text, uuid) from public, anon;
grant execute on function public.record_payment(uuid, numeric, date, text, uuid, text, uuid) to authenticated;

-- Makbuzu iptal et (tahsilat ya da gelir); taksitler yeniden hesaplanır.
create or replace function public.void_receipt(p_receipt text)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  v_n   int := 0;
  v_m   int := 0;
begin
  if v_org is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  update public.finance_payments set voided_at = now()
  where org_id = v_org and receipt_no = p_receipt and voided_at is null;
  get diagnostics v_n = row_count;
  update public.finance_incomes set voided_at = now()
  where org_id = v_org and receipt_no = p_receipt and voided_at is null;
  get diagnostics v_m = row_count;
  if v_n + v_m = 0 then
    raise exception 'FINANCE_RECEIPT_NOT_FOUND';
  end if;
  return v_n + v_m;
end;
$$;
revoke all on function public.void_receipt(text) from public, anon;
grant execute on function public.void_receipt(text) to authenticated;

-- Sonradan indirim / burs: ödenmemiş tutardan, son vadeli taksitten
-- başlayarak düşülür; sıfırlanan taksit silinir.
create or replace function public.add_fee_discount(
  p_fee uuid, p_kind text, p_amount numeric, p_note text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_fee  public.finance_fees%rowtype;
  v_left numeric := round(p_amount, 2);
  r      record;
  v_cut  numeric;
begin
  select * into v_fee from public.finance_fees where id = p_fee;
  if not found or not public.is_finance_admin(v_fee.org_id) then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  if v_fee.status <> 'active' then
    raise exception 'FINANCE_CANCELLED';
  end if;
  if p_kind not in ('discount', 'scholarship', 'sibling', 'other') or v_left is null or v_left <= 0 then
    raise exception 'FINANCE_BAD_AMOUNT';
  end if;
  if v_left > (select coalesce(sum(amount - paid_amount), 0)
               from public.finance_installments where fee_id = p_fee) + 0.001 then
    raise exception 'FINANCE_DISCOUNT_TOO_BIG';
  end if;
  perform set_config('mentoria.finance_sync', 'on', true);
  insert into public.finance_discounts (tenant_id, org_id, fee_id, kind, amount, note)
  values (v_fee.tenant_id, v_fee.org_id, p_fee, p_kind, v_left, nullif(trim(p_note), ''));
  for r in
    select id, amount, paid_amount from public.finance_installments
    where fee_id = p_fee and amount > paid_amount
    order by due_on desc, created_at desc
  loop
    exit when v_left <= 0;
    v_cut := least(v_left, r.amount - r.paid_amount);
    if r.amount - v_cut <= 0 then
      delete from public.finance_installments where id = r.id;
    else
      update public.finance_installments set amount = amount - v_cut where id = r.id;
      perform public._sync_installment(r.id);
      perform set_config('mentoria.finance_sync', 'on', true);
    end if;
    v_left := v_left - v_cut;
  end loop;
  perform set_config('mentoria.finance_sync', 'off', true);
end;
$$;
revoke all on function public.add_fee_discount(uuid, text, numeric, text) from public, anon;
grant execute on function public.add_fee_discount(uuid, text, numeric, text) to authenticated;

-- Kayıt iptali ve iade: ödenmemiş taksitler silinir, kısmen ödenen taksit
-- ödenen tutara iner; iade tahsil edilen netten fazla olamaz.
-- Dönüş: {"receipt_no": iade makbuzu ya da null}
create or replace function public.cancel_fee(
  p_fee uuid, p_refund numeric, p_on date, p_method text, p_account uuid, p_note text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_fee     public.finance_fees%rowtype;
  v_net     numeric;
  v_receipt text;
  r         record;
begin
  select * into v_fee from public.finance_fees where id = p_fee;
  if not found or not public.is_finance_admin(v_fee.org_id) then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  if v_fee.status <> 'active' then
    raise exception 'FINANCE_CANCELLED';
  end if;
  perform public._finance_account_ok(v_fee.org_id, p_account);
  select coalesce(sum(case when kind = 'payment' then amount else -amount end), 0) into v_net
  from public.finance_payments where fee_id = p_fee and voided_at is null;
  if coalesce(p_refund, 0) < 0 or coalesce(p_refund, 0) > v_net + 0.001 then
    raise exception 'FINANCE_REFUND_TOO_BIG';
  end if;

  perform set_config('mentoria.finance_sync', 'on', true);
  for r in select id, paid_amount from public.finance_installments
           where fee_id = p_fee and amount > paid_amount loop
    if r.paid_amount = 0 then
      delete from public.finance_installments where id = r.id;
    else
      update public.finance_installments set amount = r.paid_amount where id = r.id;
      perform public._sync_installment(r.id);
      perform set_config('mentoria.finance_sync', 'on', true);
    end if;
  end loop;
  perform set_config('mentoria.finance_sync', 'off', true);

  update public.finance_fees
  set status = 'cancelled', cancelled_on = coalesce(p_on, current_date),
      cancel_note = nullif(trim(p_note), '')
  where id = p_fee;

  if coalesce(p_refund, 0) > 0 then
    v_receipt := public._next_receipt(v_fee.org_id, coalesce(p_on, current_date));
    insert into public.finance_payments
      (tenant_id, org_id, fee_id, kind, amount, paid_on, method, account_id,
       receipt_no, note, created_by)
    values (v_fee.tenant_id, v_fee.org_id, p_fee, 'refund', round(p_refund, 2),
            coalesce(p_on, current_date), p_method, p_account, v_receipt,
            nullif(trim(p_note), ''), auth.uid());
  end if;
  return jsonb_build_object('receipt_no', v_receipt);
end;
$$;
revoke all on function public.cancel_fee(uuid, numeric, date, text, uuid, text) from public, anon;
grant execute on function public.cancel_fee(uuid, numeric, date, text, uuid, text) to authenticated;

-- Ücret dışı gelir; makbuz no döner.
create or replace function public.record_income(
  p_on date, p_category text, p_amount numeric, p_method text, p_account uuid,
  p_student uuid, p_payer_name text, p_note text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_org     uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  v_name    text;
  v_receipt text;
begin
  if v_org is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  if p_category not in ('books', 'private_lesson', 'material', 'event', 'other')
     or p_amount is null or p_amount <= 0 then
    raise exception 'FINANCE_BAD_AMOUNT';
  end if;
  perform public._finance_account_ok(v_org, p_account);
  if p_student is not null then
    select full_name into v_name from public.profiles
    where id = p_student and role = 'student' and org_id = v_org;
    if v_name is null then
      raise exception 'FINANCE_BAD_STUDENT';
    end if;
  end if;
  v_receipt := public._next_receipt(v_org, coalesce(p_on, current_date));
  insert into public.finance_incomes
    (tenant_id, org_id, received_on, category, amount, method, account_id,
     student_id, student_name, payer_name, note, receipt_no)
  values ((select tenant_id from public.organizations where id = v_org), v_org,
          coalesce(p_on, current_date), p_category, round(p_amount, 2), p_method,
          p_account, p_student, v_name, nullif(trim(p_payer_name), ''),
          nullif(trim(p_note), ''), v_receipt);
  return v_receipt;
end;
$$;
revoke all on function public.record_income(date, text, numeric, text, uuid, uuid, text, text) from public, anon;
grant execute on function public.record_income(date, text, numeric, text, uuid, uuid, text, text) to authenticated;

-- Veli: çocuğunun ücretleri, taksitleri, indirimleri ve makbuzları.
create or replace function public.my_child_finance(p_student uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not exists (select 1 from public.parent_students
                 where parent_id = auth.uid() and student_id = p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  return jsonb_build_object(
    'org_name', (select o.name from public.profiles p
                 join public.organizations o on o.id = p.org_id where p.id = p_student),
    'fees', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', f.id, 'title', f.title, 'total', f.total, 'status', f.status,
               'student_name', f.student_name, 'payer_name', f.payer_name,
               'discount', (select coalesce(sum(amount), 0) from public.finance_discounts d
                            where d.fee_id = f.id),
               'installments', (select coalesce(jsonb_agg(jsonb_build_object(
                                  'due_on', i.due_on, 'amount', i.amount,
                                  'paid_amount', i.paid_amount, 'paid_on', i.paid_on)
                                  order by i.due_on), '[]'::jsonb)
                                from public.finance_installments i where i.fee_id = f.id),
               'payments', (select coalesce(jsonb_agg(jsonb_build_object(
                              'receipt_no', x.receipt_no, 'kind', x.kind, 'amount', x.amount,
                              'paid_on', x.paid_on, 'method', x.method)
                              order by x.paid_on desc), '[]'::jsonb)
                            from (select receipt_no, kind, sum(amount) amount,
                                         max(paid_on) paid_on, max(method) method
                                  from public.finance_payments
                                  where fee_id = f.id and voided_at is null
                                  group by receipt_no, kind,
                                           case when receipt_no is null then id end) x))
             order by f.created_at desc)
      from public.finance_fees f where f.student_id = p_student), '[]'::jsonb));
end;
$$;
revoke all on function public.my_child_finance(uuid) from public, anon;
grant execute on function public.my_child_finance(uuid) to authenticated;

-- Hatırlatma SMS'i kalan tutarı yazar (kısmi ödemede).
create or replace function public.send_payment_reminders(p_installments uuid[])
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  v_queued int := 0;
  v_no_phone int := 0;
  v_skipped int := 0;
begin
  if coalesce(cardinality(p_installments), 0) > 200 then
    raise exception 'TOO_MANY';
  end if;
  for r in
    select i.id, i.org_id, i.tenant_id, i.amount - i.paid_amount as amount, i.due_on,
           i.paid_on, i.reminded_at, f.student_name, f.payer_name, f.payer_phone,
           o.name org_name
    from public.finance_installments i
    join public.finance_fees f on f.id = i.fee_id
    join public.organizations o on o.id = i.org_id
    where i.id = any (p_installments)
  loop
    if not public.is_finance_admin(r.org_id) then
      raise exception 'FINANCE_NOT_ADMIN';
    end if;
    if r.paid_on is not null
       or (r.reminded_at is not null and r.reminded_at > now() - interval '20 hours') then
      v_skipped := v_skipped + 1;
    elsif r.payer_phone is null then
      v_no_phone := v_no_phone + 1;
    else
      insert into public.sms_outbox
        (tenant_id, org_id, installment_id, phone, body, created_by)
      values (
        r.tenant_id, r.org_id, r.id, r.payer_phone,
        format('Sayın %s, %s: %s için %s vadeli %s taksit ödemesini hatırlatırız.',
               coalesce(r.payer_name, 'Veli'), r.org_name, r.student_name,
               to_char(r.due_on, 'DD.MM.YYYY'), public.format_tl(r.amount)),
        auth.uid());
      update public.finance_installments set reminded_at = now() where id = r.id;
      v_queued := v_queued + 1;
    end if;
  end loop;
  if v_queued > 0 then
    perform public.kick_sms();
  end if;
  return jsonb_build_object('queued', v_queued, 'no_phone', v_no_phone,
                            'skipped', v_skipped);
end;
$$;
