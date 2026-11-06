-- Geri alma: 20261105100000_finance
-- Kurum finansı kayıtları (ücretler, taksitler, giderler, koç oranları) silinir.
drop table if exists public.finance_installments;
drop table if exists public.finance_fees;
drop table if exists public.finance_expenses;
drop table if exists public.coach_pay_rates;
drop function if exists public.guard_finance_row();
drop function if exists public.guard_coach_pay_rate();
drop function if exists public.is_finance_admin(uuid);
