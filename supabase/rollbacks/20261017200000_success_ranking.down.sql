-- Geri alma: 20261017200000_success_ranking
drop function if exists public.success_leaderboard(text, text, int, int);
drop function if exists public.my_success_status();
drop function if exists public.set_success_ranking(boolean);

-- Haftalık sıralama eski haline (reward_rank kolonu olmadan) döner.
drop function if exists public.avatar_leaderboard(int, int);
create or replace function public.avatar_leaderboard(p_limit int default 20, p_offset int default 0)
returns table (
  rank           int,
  student_id     uuid,
  display_name   text,
  avatar         jsonb,
  week_questions int,
  is_me          boolean
)
language sql stable security definer set search_path = ''
as $$
  with me as (
    select public.my_tenant() as tenant_id
    where public.my_tenant_active()
  ), scores as (
    select p.id, p.full_name, p.avatar,
           coalesce((select sum(q.correct + q.wrong + q.blank)
                     from public.question_logs q
                     where q.student_id = p.id
                       and q.logged_on > current_date - 7), 0)::int as week_questions
    from public.profiles p, me
    where p.tenant_id = me.tenant_id and p.role = 'student'
  ), ranked as (
    select rank() over (order by week_questions desc)::int as rank, *
    from scores
  )
  select r.rank, r.id,
         -- KVKK: yalnızca ad ve soyadın baş harfi
         split_part(trim(r.full_name), ' ', 1)
           || coalesce(' ' || nullif(left(regexp_replace(trim(r.full_name), '^.*\s', ''), 1), '')
                       || '.', ''),
         r.avatar, r.week_questions, r.id = auth.uid()
  from ranked r
  order by r.rank, r.full_name
  limit least(greatest(p_limit, 1), 50)
  offset greatest(p_offset, 0)
$$;
revoke execute on function public.avatar_leaderboard(int, int) from public, anon;
grant  execute on function public.avatar_leaderboard(int, int) to authenticated;

drop function if exists public.success_rewards(uuid);
drop function if exists public.success_scores(uuid, text, text);
drop function if exists public.leaderboard_name(text);

alter table public.organizations drop column if exists success_ranking_enabled;
