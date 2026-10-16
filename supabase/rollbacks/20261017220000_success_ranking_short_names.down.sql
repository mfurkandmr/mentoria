-- Geri alma: 20261017220000_success_ranking_short_names
-- Sıralama yeniden "Elif Y." biçimine döner.
create or replace function public.success_leaderboard(
  p_exam_type text,
  p_field     text default null,
  p_limit     int  default 20,
  p_offset    int  default 0)
returns table (
  rank         int,
  student_id   uuid,
  display_name text,
  avatar       jsonb,
  avg_net      numeric,
  exam_count   int,
  reward_rank  int,
  is_me        boolean
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_org     uuid := public.my_org();
  v_role    text := public.my_role()::text;
  v_enabled boolean;
begin
  if p_exam_type not in ('TYT', 'AYT')
     or (p_exam_type = 'AYT' and coalesce(p_field, '') not in ('SAY', 'EA', 'SOZ', 'DIL')) then
    raise exception 'INVALID_RANKING';
  end if;
  if v_org is null or not public.my_tenant_active()
     or v_role not in ('student', 'coach', 'admin') then
    raise exception 'NOT_ALLOWED';
  end if;
  select o.success_ranking_enabled into v_enabled
  from public.organizations o where o.id = v_org;
  if not v_enabled and v_role <> 'admin' then
    raise exception 'RANKING_DISABLED';
  end if;

  return query
  select s.rank, p.id, public.leaderboard_name(p.full_name), p.avatar,
         s.avg_net, s.exam_count,
         case when v_enabled then w.rank end,
         p.id = auth.uid()
  from public.success_scores(v_org, p_exam_type, p_field) s
  join public.profiles p on p.id = s.student_id
  left join public.success_scores(v_org, 'TYT', null) w
    on w.student_id = s.student_id and w.rank <= 5
  order by s.rank, p.full_name
  limit least(greatest(p_limit, 1), 50)
  offset greatest(p_offset, 0);
end;
$$;

drop function if exists public.ranking_short_name(text);
