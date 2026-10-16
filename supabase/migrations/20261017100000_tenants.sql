-- =====================================================================
-- White label 1/4: Dershaneler (tenants) ve süper admin
--
--  * tenants: markalama birimi (ad, slug, logo, renkler, aktiflik).
--    Bir dershanenin bir ya da daha çok kurumu (organizations = şube,
--    lisans/koltuk birimi) olabilir. Mevcut her kurum için bir dershane
--    oluşturulur; kurum eklerken tenant_id verilmezse otomatik açılır
--    (eski akışlar bozulmasın diye).
--  * platform_admins: tüm dershaneleri yöneten süper adminler.
--
-- Geri almak için: supabase/rollbacks/20261017100000_tenants.down.sql
-- =====================================================================

create table public.tenants (
  id              uuid primary key default gen_random_uuid(),
  name            text not null check (length(trim(name)) between 2 and 80),
  slug            text not null unique
                  check (slug ~ '^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$'),
  logo_url        text check (logo_url is null or logo_url ~ '^https?://'),
  primary_color   text not null default '#FFC531'
                  check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  secondary_color text not null default '#6C5CE7'
                  check (secondary_color ~ '^#[0-9A-Fa-f]{6}$'),
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.platform_admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------

-- "Bal Akademi İzmir" → "bal-akademi-izmir"
create or replace function public.slugify(p_text text)
returns text
language sql immutable set search_path = ''
as $$
  select trim(both '-' from regexp_replace(
           lower(translate(coalesce(p_text, ''),
                 'ÇĞİIÖŞÜçğıöşüÂâÎîÛû', 'cgiiosucgiosuaaiiuu')),
           '[^a-z0-9]+', '-', 'g'))
$$;

-- Boş olmayan, kurala uyan ve benzersiz bir slug üretir.
create or replace function public.unique_tenant_slug(p_text text)
returns text
language plpgsql set search_path = ''
as $$
declare
  v_base text := left(public.slugify(p_text), 28);
  v_slug text;
  v_n    int := 1;
begin
  if length(v_base) < 3 then
    v_base := 'dershane';
  end if;
  v_base := trim(both '-' from v_base);
  v_slug := v_base;
  while exists (select 1 from public.tenants where slug = v_slug) loop
    v_n := v_n + 1;
    v_slug := v_base || '-' || v_n;
  end loop;
  return v_slug;
end;
$$;

create or replace function public.is_super_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid())
$$;

-- Karışan karakterler (0/O, 1/I) olmadan 8 haneli, benzersiz davet kodu.
create or replace function public.new_invite_code()
returns text
language plpgsql set search_path = ''
as $$
declare
  v_code text;
begin
  loop
    select string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
    into v_code
    from generate_series(1, 8);
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;
  return v_code;
end;
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger tenants_touch
  before update on public.tenants
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- Kurumlar dershaneye bağlanır
-- ---------------------------------------------------------------------
alter table public.organizations
  add column tenant_id uuid references public.tenants (id) on delete restrict;

-- Mevcut her kurum için bir dershane (varsayılan Mentoria renkleriyle).
do $$
declare
  r record;
  v_tenant uuid;
begin
  for r in select id, name from public.organizations where tenant_id is null order by created_at loop
    insert into public.tenants (name, slug)
    values (left(r.name, 80), public.unique_tenant_slug(r.name))
    returning id into v_tenant;
    update public.organizations set tenant_id = v_tenant where id = r.id;
  end loop;
end;
$$;

alter table public.organizations alter column tenant_id set not null;
create index on public.organizations (tenant_id);

-- tenant_id verilmeden kurum eklenirse (ör. elle SQL ile) dershane de açılır.
create or replace function public.organizations_default_tenant()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.tenant_id is null then
    insert into public.tenants (name, slug)
    values (left(new.name, 80), public.unique_tenant_slug(new.name))
    returning id into new.tenant_id;
  end if;
  return new;
end;
$$;

create trigger organizations_default_tenant
  before insert on public.organizations
  for each row execute function public.organizations_default_tenant();

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.tenants         enable row level security;
alter table public.platform_admins enable row level security;

create policy "members read own tenant" on public.tenants
  for select to authenticated using (
    (select public.is_super_admin())
    or id = (select o.tenant_id from public.organizations o
             where o.id = (select public.my_org())));
create policy "super admin inserts tenants" on public.tenants
  for insert to authenticated with check ((select public.is_super_admin()));
create policy "super admin updates tenants" on public.tenants
  for update to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));
create policy "super admin deletes tenants" on public.tenants
  for delete to authenticated using ((select public.is_super_admin()));

create policy "read own platform admin row" on public.platform_admins
  for select to authenticated using (user_id = (select auth.uid()));
-- platform_admins'e yazma yalnızca SQL ile (service role / dashboard).
revoke insert, update, delete on public.platform_admins from anon, authenticated;

-- ---------------------------------------------------------------------
-- Herkese açık markalama (giriş ekranı, slug ile)
-- ---------------------------------------------------------------------
create or replace function public.tenant_branding(p_slug text)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
           'id', t.id, 'name', t.name, 'slug', t.slug, 'logo_url', t.logo_url,
           'primary_color', t.primary_color, 'secondary_color', t.secondary_color,
           'is_active', t.is_active)
  from public.tenants t
  where t.slug = lower(trim(p_slug)) and t.is_active
$$;

-- Davet kodu kontrolü artık dershanenin markasını da döndürür
-- (davet linkiyle gelen kullanıcı kayıt ekranında kendi dershanesini görür).
-- Pasif dershanenin kodu geçersiz sayılır.
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
             'is_active', t.is_active))
  from public.invite_codes i
  join public.organizations o on o.id = i.org_id
  join public.tenants t on t.id = o.tenant_id
  where i.code = upper(trim(p_code))
    and i.expires_at > now()
    and i.used_count < i.max_uses
    and t.is_active
$$;

-- ---------------------------------------------------------------------
-- Süper admin işlemleri
-- ---------------------------------------------------------------------

-- Yeni dershane: dershane + ilk kurum + kurum müdürü davet kodu.
create or replace function public.create_tenant(
  p_name            text,
  p_slug            text,
  p_primary_color   text default '#FFC531',
  p_secondary_color text default '#6C5CE7',
  p_logo_url        text default null,
  p_seat_limit      int  default 50)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_tenant uuid;
  v_org    uuid;
  v_code   text;
begin
  if not public.is_super_admin() then
    raise exception 'NOT_ALLOWED';
  end if;
  if exists (select 1 from public.tenants where slug = lower(trim(p_slug))) then
    raise exception 'SLUG_TAKEN';
  end if;

  insert into public.tenants (name, slug, primary_color, secondary_color, logo_url)
  values (trim(p_name), lower(trim(p_slug)), upper(p_primary_color),
          upper(p_secondary_color), nullif(trim(p_logo_url), ''))
  returning id into v_tenant;

  insert into public.organizations (name, seat_limit, tenant_id)
  values (trim(p_name), greatest(0, p_seat_limit), v_tenant)
  returning id into v_org;

  v_code := public.new_invite_code();
  insert into public.invite_codes (code, org_id, target_role, created_by, max_uses)
  values (v_code, v_org, 'admin', null, 1);

  return jsonb_build_object('tenant_id', v_tenant, 'org_id', v_org, 'admin_code', v_code);
end;
$$;

-- Dershanenin (ilk kurumunun) müdürü için yeni davet kodu.
create or replace function public.create_tenant_admin_invite(p_tenant uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_org  uuid;
  v_code text;
begin
  if not public.is_super_admin() then
    raise exception 'NOT_ALLOWED';
  end if;
  select id into v_org from public.organizations
  where tenant_id = p_tenant order by created_at limit 1;
  if v_org is null then
    raise exception 'TENANT_HAS_NO_ORG';
  end if;
  v_code := public.new_invite_code();
  insert into public.invite_codes (code, org_id, target_role, max_uses)
  values (v_code, v_org, 'admin', 1);
  return v_code;
end;
$$;

-- Erişim hakları
revoke execute on function public.is_super_admin()                  from public, anon;
grant  execute on function public.is_super_admin()                  to authenticated;
revoke execute on function public.tenant_branding(text)             from public;
grant  execute on function public.tenant_branding(text)             to anon, authenticated;
revoke execute on function public.check_invite(text)                from public;
grant  execute on function public.check_invite(text)                to anon, authenticated;
revoke execute on function public.create_tenant(text, text, text, text, text, int) from public, anon;
grant  execute on function public.create_tenant(text, text, text, text, text, int) to authenticated;
revoke execute on function public.create_tenant_admin_invite(uuid)  from public, anon;
grant  execute on function public.create_tenant_admin_invite(uuid)  to authenticated;
revoke execute on function public.new_invite_code()                 from public, anon, authenticated;
revoke execute on function public.unique_tenant_slug(text)          from public, anon, authenticated;
revoke execute on function public.organizations_default_tenant()    from public, anon, authenticated;
