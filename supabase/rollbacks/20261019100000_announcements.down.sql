-- Geri alma: 20261019100000_announcements
drop function if exists public.my_announcements();
drop function if exists public.send_announcement(text, text, text);
drop table if exists public.announcements;

delete from public.notifications where kind = 'announcement';
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan'));
