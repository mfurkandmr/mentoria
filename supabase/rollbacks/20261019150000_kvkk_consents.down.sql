-- Geri al: 20261019150000_kvkk_consents.sql (ters sırayla).

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'overdue-deletion-requests') then
      perform cron.unschedule('overdue-deletion-requests');
    end if;
    if exists (select 1 from cron.job where jobname = 'storage-cleanup') then
      perform cron.unschedule('storage-cleanup');
    end if;
  end if;
end;
$$;

drop trigger if exists queue_mistake_photo_cleanup on public.mistake_cards;
drop function if exists public.queue_mistake_photo_cleanup();
drop function if exists public.kick_storage_cleanup();
drop table if exists public.storage_cleanup;
drop function if exists public.process_overdue_deletion_requests();
drop function if exists public.export_my_data();

-- apply_signup_invite: 20261018160000_signup_after_email_confirm.sql sürümü
create or replace function public.apply_signup_invite(
  p_user_id uuid,
  p_meta jsonb,
  p_apply boolean
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_code   text := upper(trim(p_meta ->> 'invite_code'));
  v_name   text := trim(p_meta ->> 'full_name');
  v_invite public.invite_codes%rowtype;
  v_seats  int;
  v_used   int;
begin
  if v_code is null or v_code = '' then
    raise exception 'INVITE_REQUIRED';
  end if;
  if v_name is null or length(v_name) < 3 then
    raise exception 'NAME_REQUIRED';
  end if;

  select * into v_invite
  from public.invite_codes
  where code = v_code
  for update;

  if not found
     or v_invite.expires_at <= now()
     or v_invite.used_count >= v_invite.max_uses then
    raise exception 'INVITE_INVALID';
  end if;

  -- Öğrenci lisans kotası kontrolü
  if v_invite.target_role = 'student' then
    select seat_limit into v_seats
    from public.organizations
    where id = v_invite.org_id
      and (license_expires_at is null or license_expires_at > now());
    if not found then
      raise exception 'LICENSE_EXPIRED';
    end if;

    select count(*) into v_used
    from public.profiles
    where org_id = v_invite.org_id and role = 'student';
    if v_used >= v_seats then
      raise exception 'SEAT_LIMIT_REACHED';
    end if;
  end if;

  if not p_apply then
    return;
  end if;

  insert into public.profiles (id, full_name, role, org_id, kvkk_consent_at)
  values (
    p_user_id,
    v_name,
    v_invite.target_role,
    v_invite.org_id,
    case when (p_meta ->> 'kvkk_consent')::boolean then now() end
  );

  if v_invite.target_role = 'student' then
    insert into public.coach_students (coach_id, student_id, org_id)
    values (v_invite.coach_id, p_user_id, v_invite.org_id);
  elsif v_invite.target_role = 'parent' then
    insert into public.parent_students (parent_id, student_id)
    values (p_user_id, v_invite.student_id);
  end if;

  update public.invite_codes
  set used_count = used_count + 1
  where code = v_code;
end;
$$;

-- check_invite: 20261018110000_tenant_fonts.sql sürümü
create or replace function public.check_invite(p_code text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
           'role', i.target_role,
           'org_name', o.name,
           'tenant', jsonb_build_object(
             'id', t.id, 'name', t.name, 'slug', t.slug, 'logo_url', t.logo_url,
             'primary_color', t.primary_color,
             'secondary_color', t.secondary_color,
             'font_family', t.font_family,
             'is_active', t.is_active))
  from public.invite_codes i
  join public.organizations o on o.id = i.org_id
  join public.tenants t on t.id = o.tenant_id
  where i.code = upper(trim(p_code))
    and i.expires_at > now()
    and i.used_count < i.max_uses
    and t.is_active
$$;

-- success_scores: 20261017200000_success_ranking.sql sürümü
create or replace function public.success_scores(p_org uuid, p_exam_type text, p_field text)
returns table (student_id uuid, avg_net numeric, exam_count int, rank int)
language sql stable security definer set search_path = ''
as $$
  with e as (
    select ex.student_id,
           (select coalesce(sum(r.net), 0) from public.exam_subject_results r
            where r.exam_id = ex.id) as total,
           row_number() over (partition by ex.student_id
                              order by ex.taken_on desc, ex.created_at desc) as rn
    from public.exams ex
    join public.profiles p on p.id = ex.student_id
    where p.org_id = p_org and p.role = 'student'
      and ex.exam_type::text = p_exam_type
      and (p_exam_type <> 'AYT' or ex.field::text = p_field)
  ), s as (
    select e.student_id, round(avg(e.total), 2) as avg_net, count(*)::int as exam_count
    from e where e.rn <= 5
    group by e.student_id
  )
  select s.student_id, s.avg_net, s.exam_count,
         rank() over (order by s.avg_net desc)::int
  from s
$$;

-- avatar_leaderboard: 20261017200000_success_ranking.sql sürümü
create or replace function public.avatar_leaderboard(p_limit int default 20, p_offset int default 0)
returns table (
  rank           int,
  student_id     uuid,
  display_name   text,
  avatar         jsonb,
  week_questions int,
  is_me          boolean,
  reward_rank    int
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
  select r.rank, r.id, public.leaderboard_name(r.full_name),
         r.avatar, r.week_questions, r.id = auth.uid(), w.reward_rank
  from ranked r
  cross join me
  left join public.success_rewards(me.tenant_id) w on w.student_id = r.id
  order by r.rank, r.full_name
  limit least(greatest(p_limit, 1), 50)
  offset greatest(p_offset, 0)
$$;

drop function if exists public.create_invite(public.user_role, uuid, integer, boolean);
-- create_invite: 20261017170000_account_rules.sql sürümü
create or replace function public.create_invite(
  p_target_role public.user_role,
  p_coach uuid default null,
  p_max_uses int default 1
)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_me      public.profiles%rowtype;
  v_code    text;
  v_coach   uuid;
  v_student uuid;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if v_me.role = 'admin' and p_target_role = 'coach' then
    null;
  elsif v_me.role = 'admin' and p_target_role = 'student' then
    if not exists (
      select 1 from public.profiles
      where id = p_coach and role = 'coach' and org_id = v_me.org_id
    ) then
      raise exception 'COACH_NOT_IN_ORG';
    end if;
    v_coach := p_coach;
  elsif v_me.role = 'coach' and p_target_role = 'student' then
    v_coach := v_me.id;
  elsif v_me.role = 'student' and p_target_role = 'parent' then
    v_student := v_me.id;
  else
    raise exception 'NOT_ALLOWED';
  end if;

  loop
    select string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
    into v_code
    from generate_series(1, 8);
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;

  insert into public.invite_codes
    (code, org_id, target_role, coach_id, student_id, created_by, max_uses, expires_at)
  values
    (v_code, v_me.org_id, p_target_role, v_coach, v_student, v_me.id,
     greatest(1, least(p_max_uses, 200)),
     now() + case when p_target_role = 'parent'
                  then interval '30 days' else interval '14 days' end);

  return v_code;
end;
$$;
revoke execute on function public.create_invite(public.user_role, uuid, integer) from public, anon;
grant execute on function public.create_invite(public.user_role, uuid, integer) to authenticated;

alter table public.invite_codes drop column if exists guardian_statement_at;

drop function if exists public.consent_status(uuid);
drop function if exists public.set_consent(text, boolean, text, uuid);
drop function if exists public.ranking_visible(uuid);
drop function if exists public.has_consent(uuid, text);
drop table if exists public.consents;
drop function if exists public.set_birth_year(int, uuid);
drop function if exists public.is_minor(uuid);
alter table public.profiles drop column if exists birth_year;
