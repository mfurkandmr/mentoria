-- Geri alma: 20261018210000_daily_question
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('daily-question');
    exception when others then
      raise notice 'daily-question yok: %', sqlerrm;
    end;
  end if;
end;
$$;

drop function if exists public.send_daily_questions(timestamptz);
drop function if exists public.my_daily_question();
drop table if exists public.daily_answers;
drop function if exists public.guard_daily_answer();
drop function if exists public.daily_question_id(uuid, date);

delete from public.notifications where kind = 'daily_question';
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report'));
