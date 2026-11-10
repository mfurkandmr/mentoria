-- 20261109150000_staff_cheques geri alma. Personel kartları, izinler ve çek
-- kayıtları silinir; onlardan doğan gider ve tahsilat kayıtları kalır.

drop function if exists public.set_cheque_status(uuid, text, date, uuid, text);
drop table if exists public.finance_cheques;
drop function if exists public.guard_cheque_delete();
drop function if exists public.guard_cheque_insert();

drop trigger if exists guard_finance_zstaff on public.finance_expenses;
drop function if exists public.guard_expense_staff();
alter table public.finance_expenses
  drop constraint if exists finance_expenses_one_payee,
  drop column if exists staff_name,
  drop column if exists staff_id;
alter table public.finance_expenses
  add constraint finance_expenses_one_payee
    check (coach_id is null or teacher_id is null);

drop table if exists public.staff_leaves;
drop table if exists public.staff_members;
drop function if exists public.guard_staff_leave();
drop function if exists public.guard_staff_member();
