-- 20261109140000_teacher_pay geri alma. Öğretmen ücretleri silinir; öğretmene
-- bağlı giderler kalır, yalnızca öğretmen bağlantısı ve adı kaybolur.

drop trigger if exists guard_finance_zteacher on public.finance_expenses;
drop function if exists public.guard_expense_teacher();

alter table public.finance_expenses
  drop constraint if exists finance_expenses_one_payee,
  drop column if exists teacher_name,
  drop column if exists teacher_id;

drop table if exists public.teacher_pay_rates;
drop function if exists public.guard_teacher_pay_rate();
