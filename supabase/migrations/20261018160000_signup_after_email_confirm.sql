-- =====================================================================
-- Kayıt, e-posta doğrulanınca tamamlanır
-- ---------------------------------------------------------------------
-- Uygulama kayıtta e-postaya doğrulama kodu yollar (Supabase Auth,
-- "Confirm email" açık). Eskiden profil, ilişki ve davet kullanımı
-- `auth.users` satırı eklenir eklenmez yazılıyordu: olmayan bir adresle
-- kayıt olan biri daveti (çoğu tek kullanımlık) ve öğrenci koltuğunu
-- doğrulamadan harcıyordu.
--
-- Şimdi:
--   * Ekleme anında davet yalnızca DENETLENİR (geçersizse kayıt hemen
--     reddedilir, kullanıcı boşuna kod beklemez).
--   * Adres doğrulanınca (email_confirmed_at boş → dolu) profil, koç /
--     veli ilişkisi yazılır ve davet kullanılmış sayılır.
--   * Adres eklenirken zaten doğrulanmışsa ("Confirm email" kapalı, ya da
--     panelden oluşturulan kullanıcı) eskisi gibi hemen yazılır.
--
-- Geri almak için: supabase/rollbacks/20261018160000_signup_after_email_confirm.down.sql
-- =====================================================================

-- Davetle kaydın ortak gövdesi. p_apply = false: yalnızca denetle.
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

-- Yalnızca tetikleyiciler çağırır.
revoke all on function public.apply_signup_invite(uuid, jsonb, boolean)
  from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  perform public.apply_signup_invite(
    new.id,
    new.raw_user_meta_data,
    new.email_confirmed_at is not null
  );
  return new;
end;
$$;

create or replace function public.handle_user_email_confirmed()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.email_confirmed_at is null
     and new.email_confirmed_at is not null
     and not exists (select 1 from public.profiles where id = new.id) then
    perform public.apply_signup_invite(new.id, new.raw_user_meta_data, true);
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_confirmed on auth.users;
create trigger on_auth_user_email_confirmed
  after update of email_confirmed_at on auth.users
  for each row execute function public.handle_user_email_confirmed();
