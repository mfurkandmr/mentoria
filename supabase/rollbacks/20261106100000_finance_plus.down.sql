-- 20261106100000_finance_plus geri alma. Kısmi ödeme, indirim, iade,
-- gelir, hesap ve makbuz kayıtları silinir; taksitlerin ödendi günü kalır.

drop function if exists public.my_child_finance(uuid);
drop function if exists public.record_income(date, text, numeric, text, uuid, uuid, text, text);
drop function if exists public.cancel_fee(uuid, numeric, date, text, uuid, text);
drop function if exists public.add_fee_discount(uuid, text, numeric, text);
drop function if exists public.void_receipt(text);
drop function if exists public.record_payment(uuid, numeric, date, text, uuid, text, uuid);
drop function if exists public.create_fees_bulk(uuid[], text, numeric, jsonb, jsonb, text, int);
drop function if exists public.create_fee(uuid, text, numeric, jsonb, jsonb, text, int, text, text);
drop function if exists public._finance_account_ok(uuid, uuid);
drop function if exists public._next_receipt(uuid, date);

drop trigger if exists guard_fee_delete on public.finance_fees;
drop function if exists public.guard_fee_delete();
drop trigger if exists sync_installment_payment on public.finance_payments;
drop function if exists public.sync_installment_payment();
drop function if exists public._sync_installment(uuid);
drop trigger if exists guard_installment_paid on public.finance_installments;
drop function if exists public.guard_installment_paid();
drop trigger if exists guard_finance_zaccount on public.finance_expenses;
drop function if exists public.guard_expense_account();

drop table if exists public.finance_receipt_seq;
drop table if exists public.fee_plans;
drop table if exists public.finance_transfers;
drop table if exists public.finance_incomes;
drop table if exists public.finance_payments;
drop table if exists public.finance_discounts;
alter table public.finance_expenses drop column if exists account_id;
drop table if exists public.finance_accounts;
drop function if exists public.guard_finance_extra();

alter table public.finance_installments drop column if exists paid_amount;
alter table public.finance_fees
  drop column if exists status, drop column if exists cancelled_on,
  drop column if exists cancel_note;

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
    select i.id, i.org_id, i.tenant_id, i.amount, i.due_on, i.paid_on,
           i.reminded_at, f.student_name, f.payer_name, f.payer_phone,
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
