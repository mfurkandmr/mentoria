-- Geri alma: 20261105110000_finance_reminders
-- SMS kuyruğu, günlük taksit bildirimi ve ödeme günü / veli alanları kalkar;
-- bildirim türleri 20261031140000_risk_alerts listesine döner.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job
    where jobname in ('due-installments', 'sms-outbox');
  end if;
end;
$$;

drop function if exists public.send_payment_reminders(uuid[]);
drop function if exists public.notify_due_installments(timestamptz);
drop function if exists public.kick_sms();
drop function if exists public.format_tl(numeric);
drop table if exists public.sms_outbox;

delete from public.notifications where kind = 'installment_due';
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest'));

drop trigger if exists guard_finance_payer on public.finance_fees;
drop function if exists public.guard_finance_payer();
alter table public.finance_installments
  drop column if exists due_notified_at,
  drop column if exists reminded_at;
alter table public.finance_fees
  drop column if exists due_day,
  drop column if exists payer_name,
  drop column if exists payer_phone;
