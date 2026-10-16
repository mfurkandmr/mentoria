-- Geri alma: 20261018180000_security_hardening
-- İzinler Supabase'in varsayılanına döner (anon ve authenticated tüm
-- tablolarda tüm haklar; asıl koruma yine RLS), logo denetimi eski haline.

alter table public.question_logs drop constraint if exists question_logs_total_check;

grant update (avatar_url) on public.profiles to authenticated;

create or replace function public.update_my_branding(
  p_name            text,
  p_primary_color   text,
  p_secondary_color text,
  p_logo_url        text default null,
  p_font_family     text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_tenant uuid := public.my_tenant();
  v_logo   text := nullif(trim(p_logo_url), '');
  v_font   text := nullif(lower(trim(p_font_family)), '');
begin
  if v_tenant is null or public.my_role() <> 'admin' then
    raise exception 'NOT_ALLOWED';
  end if;
  if length(trim(coalesce(p_name, ''))) < 2 then
    raise exception 'NAME_REQUIRED';
  end if;
  -- Logo yalnızca bu dershanenin Storage klasöründen olabilir.
  if v_logo is not null
     and v_logo not like '%/storage/v1/object/public/tenant-logos/' || v_tenant::text || '/%' then
    raise exception 'LOGO_NOT_ALLOWED';
  end if;
  if v_font is not null and v_font not in (
       'nunito', 'poppins', 'merriweather', 'playfair_display', 'roboto_slab',
       'oswald', 'baloo_2', 'patrick_hand', 'space_mono', 'exo_2') then
    raise exception 'INVALID_FONT';
  end if;

  update public.tenants
  set name = left(trim(p_name), 80),
      primary_color = upper(p_primary_color),
      secondary_color = upper(p_secondary_color),
      logo_url = v_logo,
      font_family = coalesce(v_font, font_family)
  where id = v_tenant;

  -- Tek kurumlu dershanede kurum adı da aynı olsun.
  if (select count(*) from public.organizations where tenant_id = v_tenant) = 1 then
    update public.organizations
    set name = left(trim(p_name), 80)
    where tenant_id = v_tenant and name is distinct from left(trim(p_name), 80);
  end if;
end;
$$;

drop function if exists public.logo_url_allowed(text, uuid);

alter table public.tenants drop constraint if exists tenants_logo_url_check;
alter table public.tenants add constraint tenants_logo_url_check
  check (logo_url is null or logo_url ~ '^https?://');

-- handle_user_email_confirmed: tetikleyici olarak çalışmaya devam eder;
-- dış çağrı izni geri verilmez (zaten tetikleyici dışında çalışmaz).

alter default privileges in schema public grant all on tables to anon;
alter default privileges in schema public grant all on tables to authenticated;
grant all on all tables in schema public to anon;
grant truncate, trigger, references on all tables in schema public to authenticated;
