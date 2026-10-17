-- Geri alma: 20261018230000_duels
drop function if exists public.my_duels();
drop function if exists public.finish_duel(uuid, smallint[]);
drop function if exists public.start_duel(uuid);
drop function if exists public.create_duel(uuid, text);
drop function if exists public.duel_opponents();

delete from public.user_unlocked_items where item_id in (44, 45, 46);
update public.profiles set avatar = avatar - 'accessory' where (avatar ->> 'accessory')::int in (44, 45);
update public.profiles set avatar = avatar - 'outfit' where (avatar ->> 'outfit')::int = 46;
delete from public.avatar_items where id in (44, 45, 46);

create or replace function public.avatar_rule_met(p_user uuid, p_rule jsonb)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
begin
  return case p_rule ->> 'type'
    when 'free'   then true
    when 'streak' then public.student_best_streak(p_user) >= coalesce((p_rule ->> 'days')::int, 1)
    when 'net'    then public.student_best_net(p_user, p_rule ->> 'exam_type')
                         >= coalesce((p_rule ->> 'value')::numeric, 0)
    when 'badge'  then public.student_has_badge(p_user, p_rule ->> 'badge')
    when 'questions' then (
      select coalesce(sum(correct + wrong + blank), 0)
      from public.question_logs where student_id = p_user
    ) >= coalesce((p_rule ->> 'count')::int, 1)
    when 'study_minutes' then (
      select coalesce(sum(duration_sec), 0) / 60
      from public.study_sessions where student_id = p_user
    ) >= coalesce((p_rule ->> 'minutes')::int, 1)
    when 'topics' then (
      select count(*) from public.topic_progress
      where student_id = p_user and status = 'done'
    ) >= coalesce((p_rule ->> 'count')::int, 1)
    when 'exams' then (
      select count(*) from public.exams where student_id = p_user
    ) >= coalesce((p_rule ->> 'count')::int, 1)
    else false
  end;
end;
$$;
revoke execute on function public.avatar_rule_met(uuid, jsonb) from public, anon, authenticated;

delete from public.notifications where kind in ('duel', 'duel_result');
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question'));

drop table if exists public.duels;
drop table if exists public.practice_keys;
