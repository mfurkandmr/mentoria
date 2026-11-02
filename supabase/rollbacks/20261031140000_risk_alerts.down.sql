-- Geri alma: 20261031140000_risk_alerts
-- Risk bildirimleri silinir; bildirim türleri 20261029100000_retention_jobs
-- listesine döner.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'risk-digests';
  end if;
end;
$$;

drop function if exists public.send_risk_digests(timestamptz);
drop function if exists public.my_risk_list(int);
drop function if exists public.risk_rows(uuid[], timestamptz);
drop function if exists public.risk_score(jsonb);

delete from public.notifications where kind = 'risk_digest';
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning'));
