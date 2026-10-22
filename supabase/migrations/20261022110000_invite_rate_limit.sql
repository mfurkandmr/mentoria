-- Davet kodu tahminine karşı önlemler.
--
-- 1. random_code(): kodlar random() yerine gen_random_uuid() ile üretilir.
--    gen_random_uuid() işletim sisteminin güvenli rastgele kaynağını
--    (pg_strong_random) kullanır; pgcrypto eklentisi gerekmez. Kod biçimi
--    aynı: kişisel davet 8 karakter, kurum kodu MENTORIA- + 6 karakter.
-- 2. check_invite(): girişsiz çağrılabildiği için hatalı denemeler sayılır.
--    IP başına 10 dakikada 20, toplamda 10 dakikada 1000 hatalı denemeden
--    sonra TOO_MANY_ATTEMPTS döner. IP, x-forwarded-for başlığının ilk
--    değeridir; bu değer taklit edilebileceği için toplam sınır da vardır.
--    Doğru kod sayaca yazılmaz; sınır dolunca doğru kod da beklemek zorunda
--    kalır (yoksa sınır tahmini durdurmaz).

-- 1. Güvenli kod üretici ---------------------------------------------------------
-- Her karakter ayrı bir UUID'nin ilk baytından gelir (ilk bayt tamamen
-- rastgele). 256, 32'ye tam bölündüğü için dağılım eşittir.
create or replace function public.random_code(p_len int)
returns text
language plpgsql volatile set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_out text := '';
begin
  for i in 1 .. p_len loop
    v_out := v_out || substr(v_alphabet,
      1 + get_byte(uuid_send(gen_random_uuid()), 0) % 32, 1);
  end loop;
  return v_out;
end;
$$;
revoke all on function public.random_code(int) from public, anon, authenticated;

create or replace function public.generate_org_invite_code()
returns text
language plpgsql volatile set search_path = ''
as $$
declare
  v_code text;
begin
  loop
    v_code := 'MENTORIA-' || public.random_code(6);
    exit when not exists (select 1 from public.organizations where invite_code = v_code)
          and not exists (select 1 from public.invite_codes where code = v_code);
  end loop;
  return v_code;
end;
$$;
revoke execute on function public.generate_org_invite_code() from public, anon, authenticated;

-- Kişisel davet: yalnızca kod üretimi değişti, gerisi 20261020100000 ile aynı.
create or replace function public.create_invite(
  p_target_role public.user_role,
  p_coach uuid default null,
  p_max_uses integer default 1,
  p_guardian_statement boolean default false
) returns text
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
    -- Yetişkin öğrenci velisini ancak açık rızasıyla ekler.
    if not public.is_minor(v_me.id) and not public.has_consent(v_me.id, 'parent_view') then
      raise exception 'PARENT_VIEW_CONSENT_REQUIRED';
    end if;
  else
    raise exception 'NOT_ALLOWED';
  end if;

  if p_target_role = 'student' then
    if not exists (select 1 from public.organizations
                   where id = v_me.org_id and is_active) then
      raise exception 'ORG_INACTIVE';
    end if;
    if not exists (select 1 from public.organizations
                   where id = v_me.org_id and credit_balance > 0) then
      raise exception 'NO_CREDITS';
    end if;
  end if;

  loop
    v_code := public.random_code(8);
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;

  insert into public.invite_codes
    (code, org_id, target_role, coach_id, student_id, created_by, max_uses, expires_at,
     guardian_statement_at)
  values
    (v_code, v_me.org_id, p_target_role, v_coach, v_student, v_me.id,
     greatest(1, least(p_max_uses, 200)),
     now() + case when p_target_role = 'parent'
                  then interval '30 days' else interval '14 days' end,
     case when p_target_role = 'student' and p_guardian_statement then now() end);

  return v_code;
end;
$$;

-- 2. Hatalı deneme sayacı ---------------------------------------------------------
create table public.invite_check_failures (
  id bigint generated always as identity primary key,
  ip text not null,
  at timestamptz not null default now()
);
create index invite_check_failures_ip_at on public.invite_check_failures (ip, at);
create index invite_check_failures_at on public.invite_check_failures (at);
alter table public.invite_check_failures enable row level security;
revoke all on public.invite_check_failures from anon, authenticated;

create or replace function public.check_invite(p_code text)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_ip text := coalesce(nullif(trim(split_part(
      coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json
        ->> 'x-forwarded-for', ',', 1)), ''), 'unknown');
  v_result jsonb;
begin
  if (select count(*) from public.invite_check_failures
      where ip = v_ip and at > now() - interval '10 minutes') >= 20
     or (select count(*) from public.invite_check_failures
         where at > now() - interval '10 minutes') >= 1000 then
    raise exception 'TOO_MANY_ATTEMPTS';
  end if;

  select * into v_result from (
  select jsonb_build_object(
             'role', i.target_role,
             'org_name', o.name,
             -- Veli davetinde: çocuk 18 yaşından küçükse veli onayı istenir.
             'student_minor', case when i.target_role = 'parent'
                                   then public.is_minor(i.student_id) end,
             'no_credits', i.target_role = 'student' and o.credit_balance <= 0,
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
      and o.is_active
    union all
    select jsonb_build_object(
             'role', 'student',
             'org_name', o.name,
             'student_minor', null,
             'no_credits', o.credit_balance <= 0,
             'tenant', jsonb_build_object(
               'id', t.id, 'name', t.name, 'slug', t.slug, 'logo_url', t.logo_url,
               'primary_color', t.primary_color,
               'secondary_color', t.secondary_color,
               'font_family', t.font_family,
               'is_active', t.is_active))
    from public.organizations o
    join public.tenants t on t.id = o.tenant_id
    where o.invite_code = upper(trim(p_code))
      and o.is_active
      and t.is_active
      and (o.license_expires_at is null or o.license_expires_at > now())
    limit 1
  ) r;

  if v_result is null then
    delete from public.invite_check_failures where at < now() - interval '1 hour';
    insert into public.invite_check_failures (ip) values (v_ip);
  end if;
  return v_result;
end;
$$;
