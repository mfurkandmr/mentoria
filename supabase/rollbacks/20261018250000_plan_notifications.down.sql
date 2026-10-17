-- Geri alma: 20261018250000_plan_notifications
drop trigger if exists notify_plan_item on public.plan_items;
drop function if exists public.notify_plan_item();

delete from public.notifications where kind = 'plan';
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result'));
