-- 20261120110000_duel_consent geri alma: rıza kontrolsüz önceki sürümler.

create or replace function public.duel_opponents()
returns table (student_id uuid, display_name text, avatar jsonb)
language sql stable security definer set search_path = ''
as $$
  select p.id, public.leaderboard_name(p.full_name), p.avatar
  from public.profiles p
  where public.my_role() = 'student'
    and public.my_tenant_active()
    and p.role = 'student'
    and p.org_id = public.my_org()
    and p.tenant_id = public.my_tenant()
    and p.id <> auth.uid()
  order by p.full_name
$$;
revoke execute on function public.duel_opponents() from public, anon;
grant execute on function public.duel_opponents() to authenticated;

create or replace function public.create_duel(p_opponent uuid, p_subject text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_me  public.profiles%rowtype;
  v_op  public.profiles%rowtype;
  v_ids text[];
  v_id  uuid;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found or v_me.role <> 'student' or not public.my_tenant_active() then
    raise exception 'DUEL_NOT_ALLOWED';
  end if;
  select * into v_op from public.profiles where id = p_opponent;
  if not found or v_op.role <> 'student' or v_op.id = v_me.id
     or v_op.org_id is distinct from v_me.org_id
     or v_op.tenant_id is distinct from v_me.tenant_id then
    raise exception 'DUEL_BAD_OPPONENT';
  end if;
  if exists (select 1 from public.duels d
             where d.decided_at is null and d.expires_at > now()
               and ((d.challenger = v_me.id and d.opponent = v_op.id)
                 or (d.challenger = v_op.id and d.opponent = v_me.id))) then
    raise exception 'DUEL_ALREADY_OPEN';
  end if;
  if (select count(*) from public.duels
      where challenger = v_me.id and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'DUEL_DAILY_LIMIT';
  end if;

  select array_agg(question_id) into v_ids from (
    select question_id from public.practice_keys
    where split_part(question_id, '-', 1) = p_subject
    order by random() limit 10
  ) q;
  if coalesce(cardinality(v_ids), 0) < 10 then
    raise exception 'DUEL_BAD_SUBJECT';
  end if;

  insert into public.duels (tenant_id, challenger, opponent, subject_code, question_ids)
  values (v_me.tenant_id, v_me.id, v_op.id, p_subject, v_ids)
  returning id into v_id;

  insert into public.notifications (user_id, kind, ref_id, data)
  values (v_op.id, 'duel', v_id, jsonb_build_object(
    'from', public.leaderboard_name(v_me.full_name),
    'subject', p_subject,
    'route', '/student/duels'));
  return v_id;
end;
$$;
