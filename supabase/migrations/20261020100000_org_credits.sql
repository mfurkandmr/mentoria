-- Kurum kredisi ve kurum davet kodu (20 Ekim 2026)
--
-- 1. organizations: credit_balance (öğrenci kredisi), invite_code
--    (MENTORIA-XXXXXX), is_active. Bitiş tarihi için mevcut
--    license_expires_at kullanılır (ayrı plan_expires_at açılmadı).
-- 2. generate_org_invite_code(): 'MENTORIA-' + 6 büyük harf/rakam, tekrar etmez.
-- 3. Öğrenci profili eklenince kurumun kredisi 1 azalır; kredi 0 ise
--    NO_CREDITS hatası. Kredi harcanır: öğrenci silinse de geri gelmez.
-- 4. Kayıt kurum koduyla da yapılabilir (yalnızca öğrenci). Öğrenci,
--    kurumdaki en az öğrencisi olan koça bağlanır; müdür sonra değiştirebilir.
-- 5. seat_limit artık yalnızca "başlangıç kredisi": kurum açılırken kredi
--    verilmezse seat_limit kadar kredi yazılır. Koltuk sayımı kaldırıldı.
--
-- Uygulamada fiyat, satın alma ya da ödeme yoktur. Kredi yalnızca platform
-- yöneticisi tarafından yüklenir (add_org_credits ya da SQL).

-- 1. Alanlar -------------------------------------------------------------------
alter table public.organizations
  add column credit_balance int check (credit_balance >= 0),
  add column invite_code    text unique,
  add column is_active      boolean not null default true;

-- Mevcut kurumlar: kalan koltuk kadar kredi.
update public.organizations o
set credit_balance = greatest(0, o.seat_limit - (
  select count(*) from public.profiles p
  where p.org_id = o.id and p.role = 'student'));

alter table public.organizations alter column credit_balance set not null;

-- 2. Kod üretici -----------------------------------------------------------------
-- Karışan karakterler (0/O, 1/I) kullanılmaz; kişisel davet kodlarıyla da
-- çakışmaz.
create or replace function public.generate_org_invite_code()
returns text
language plpgsql volatile set search_path = ''
as $$
declare
  v_code text;
begin
  loop
    select 'MENTORIA-' || string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
    into v_code
    from generate_series(1, 6);
    exit when not exists (select 1 from public.organizations where invite_code = v_code)
          and not exists (select 1 from public.invite_codes where code = v_code);
  end loop;
  return v_code;
end;
$$;
revoke execute on function public.generate_org_invite_code() from public, anon, authenticated;

update public.organizations
set invite_code = public.generate_org_invite_code()
where invite_code is null;

alter table public.organizations alter column invite_code set not null;

-- Yeni kurum: kod ve (verilmediyse) seat_limit kadar başlangıç kredisi.
create or replace function public.organizations_defaults()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.credit_balance := coalesce(new.credit_balance, new.seat_limit, 0);
  new.invite_code := coalesce(new.invite_code, public.generate_org_invite_code());
  return new;
end;
$$;
revoke execute on function public.organizations_defaults() from public, anon, authenticated;

create trigger organizations_defaults
  before insert on public.organizations
  for each row execute function public.organizations_defaults();

-- Kurum kodunu yalnızca müdür görür (RPC ile). Sütun okuma izni koddan
-- arındırılır. NOT: organizations'a yeni sütun eklenirse select izni de
-- ayrıca verilmeli.
revoke select on public.organizations from anon, authenticated;
do $$
declare
  v_cols text;
begin
  select string_agg(quote_ident(column_name), ', ')
  into v_cols
  from information_schema.columns
  where table_schema = 'public' and table_name = 'organizations'
    and column_name <> 'invite_code';
  execute format('grant select (%s) on public.organizations to authenticated', v_cols);
end;
$$;

-- 3. Öğrenci eklenince kredi düşer ---------------------------------------------
create or replace function public.consume_student_credit()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.organizations
  set credit_balance = credit_balance - 1
  where id = new.org_id and credit_balance > 0;
  if not found then
    raise exception 'NO_CREDITS';
  end if;
  return new;
end;
$$;
revoke execute on function public.consume_student_credit() from public, anon, authenticated;

create trigger consume_student_credit
  before insert on public.profiles
  for each row
  when (new.role = 'student' and new.org_id is not null)
  execute function public.consume_student_credit();

-- Müdür ve koçlar için: kurumun kredisi ve durumu.
create or replace function public.my_org_credits()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
           'credit_balance', o.credit_balance,
           'is_active', o.is_active,
           'license_expires_at', o.license_expires_at)
  from public.organizations o
  join public.profiles p on p.org_id = o.id
  where p.id = auth.uid() and p.role in ('admin', 'coach')
$$;
revoke execute on function public.my_org_credits() from public, anon;
grant execute on function public.my_org_credits() to authenticated;

-- Müdür: kurum kodu ve yenileme (kod sızarsa eskisi geçersiz olur).
create or replace function public.my_org_invite_code()
returns text
language sql stable security definer set search_path = ''
as $$
  select o.invite_code
  from public.organizations o
  join public.profiles p on p.org_id = o.id
  where p.id = auth.uid() and p.role = 'admin'
$$;
revoke execute on function public.my_org_invite_code() from public, anon;
grant execute on function public.my_org_invite_code() to authenticated;

create or replace function public.regenerate_org_invite_code()
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_org  uuid;
  v_code text;
begin
  select org_id into v_org from public.profiles
  where id = auth.uid() and role = 'admin';
  if v_org is null then
    raise exception 'NOT_ALLOWED';
  end if;
  v_code := public.generate_org_invite_code();
  update public.organizations set invite_code = v_code where id = v_org;
  return v_code;
end;
$$;
revoke execute on function public.regenerate_org_invite_code() from public, anon;
grant execute on function public.regenerate_org_invite_code() to authenticated;

-- Platform yöneticisi: kredi yükler (eksi değer düşer, 0'ın altına inmez).
create or replace function public.add_org_credits(p_org uuid, p_amount int)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_balance int;
begin
  if not public.is_super_admin() then
    raise exception 'NOT_ALLOWED';
  end if;
  update public.organizations
  set credit_balance = greatest(0, credit_balance + p_amount)
  where id = p_org
  returning credit_balance into v_balance;
  if not found then
    raise exception 'ORG_NOT_FOUND';
  end if;
  return v_balance;
end;
$$;
revoke execute on function public.add_org_credits(uuid, int) from public, anon;
grant execute on function public.add_org_credits(uuid, int) to authenticated;

-- 4. Davet: kredi kontrolü ve kurum kodu -----------------------------------------
-- Öğrenci daveti: kurum kapalıysa ya da kredi bittiyse davet üretilmez.
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
    select string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
    into v_code
    from generate_series(1, 8);
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

-- Kurum kodu öğrenci daveti gibi görünür. no_credits: kayıt ekranı
-- "kurumunla iletişime geç" der.
create or replace function public.check_invite(p_code text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
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
$$;

-- Kayıt: kişisel davet kodu ya da kurum kodu (MENTORIA-XXXXXX).
create or replace function public.apply_signup_invite(p_user_id uuid, p_meta jsonb, p_apply boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_code      text := upper(trim(p_meta ->> 'invite_code'));
  v_name      text := trim(p_meta ->> 'full_name');
  v_version   text := coalesce(nullif(trim(p_meta ->> 'privacy_version'), ''), '0');
  v_birth     int;
  v_invite    public.invite_codes%rowtype;
  v_org_code  boolean := false;
  v_org       public.organizations%rowtype;
begin
  if v_code is null or v_code = '' then
    raise exception 'INVITE_REQUIRED';
  end if;
  if v_name is null or length(v_name) < 3 then
    raise exception 'NAME_REQUIRED';
  end if;

  begin
    v_birth := nullif(p_meta ->> 'birth_year', '')::int;
  exception when others then
    v_birth := null;
  end;
  if v_birth is not null
     and (v_birth < 1940 or v_birth > extract(year from current_date)::int - 10) then
    v_birth := null;
  end if;

  select * into v_invite
  from public.invite_codes
  where code = v_code
  for update;

  if found then
    if v_invite.expires_at <= now() or v_invite.used_count >= v_invite.max_uses then
      raise exception 'INVITE_INVALID';
    end if;
  else
    -- Kurum kodu: yalnızca öğrenci kaydı.
    select * into v_org from public.organizations where invite_code = v_code;
    if not found then
      raise exception 'INVITE_INVALID';
    end if;
    v_org_code := true;
    v_invite.org_id := v_org.id;
    v_invite.target_role := 'student';
    -- En az öğrencisi olan koç (eşitlikte en eski koç).
    select c.id into v_invite.coach_id
    from public.profiles c
    where c.org_id = v_org.id and c.role = 'coach'
    order by (select count(*) from public.coach_students cs where cs.coach_id = c.id),
             c.created_at, c.id
    limit 1;
    if v_invite.coach_id is null then
      raise exception 'NO_COACH';
    end if;
  end if;

  -- Öğrenci: kurum açık, lisans geçerli, kredi var. (Kredi asıl olarak
  -- profil eklenirken consume_student_credit ile düşer.)
  if v_invite.target_role = 'student' then
    select * into v_org from public.organizations where id = v_invite.org_id;
    if not v_org.is_active then
      raise exception 'ORG_INACTIVE';
    end if;
    if v_org.license_expires_at is not null and v_org.license_expires_at <= now() then
      raise exception 'LICENSE_EXPIRED';
    end if;
    if v_org.credit_balance <= 0 then
      raise exception 'NO_CREDITS';
    end if;
  end if;

  if not p_apply then
    return;
  end if;

  insert into public.profiles (id, full_name, role, org_id, kvkk_consent_at, birth_year)
  values (
    p_user_id,
    v_name,
    v_invite.target_role,
    v_invite.org_id,
    case when (p_meta ->> 'kvkk_consent')::boolean then now() end,
    v_birth
  );

  if (p_meta ->> 'kvkk_consent')::boolean then
    insert into public.consents (user_id, kind, granted, version, source, given_by)
    values (p_user_id, 'privacy_notice', true, v_version, 'self', p_user_id);
  end if;

  if v_invite.target_role = 'student' then
    insert into public.coach_students (coach_id, student_id, org_id)
    values (v_invite.coach_id, p_user_id, v_invite.org_id);

    -- Kurum, davette veli onayını kendisinin aldığını beyan ettiyse.
    if v_invite.guardian_statement_at is not null then
      insert into public.consents (user_id, kind, granted, version, source, given_by)
      values (p_user_id, 'guardian_approval', true, v_version, 'institution',
              v_invite.created_by);
    end if;
    if (p_meta -> 'consents' ->> 'ranking')::boolean then
      insert into public.consents (user_id, kind, granted, version, source, given_by)
      values (p_user_id, 'ranking', true, v_version, 'self', p_user_id);
    end if;

  elsif v_invite.target_role = 'parent' then
    insert into public.parent_students (parent_id, student_id)
    values (p_user_id, v_invite.student_id);

    if (p_meta ->> 'guardian_approval')::boolean then
      insert into public.consents (user_id, kind, granted, version, source, given_by)
      values (v_invite.student_id, 'guardian_approval', true, v_version, 'parent',
              p_user_id);
    end if;
    if (p_meta ->> 'child_ranking')::boolean then
      insert into public.consents (user_id, kind, granted, version, source, given_by)
      values (v_invite.student_id, 'ranking', true, v_version, 'parent', p_user_id);
    end if;
  end if;

  if not v_org_code then
    update public.invite_codes
    set used_count = used_count + 1
    where code = v_code;
  end if;
end;
$$;
revoke all on function public.apply_signup_invite(uuid, jsonb, boolean)
  from public, anon, authenticated;
