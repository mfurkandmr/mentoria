-- Geri alma: 20261018160000_signup_after_email_confirm
-- Profil / davet kullanımı yine auth.users eklenir eklenmez yazılır.
-- Not: geri alındığında, o sırada doğrulanmamış kullanıcıların profili
-- doğrulanınca oluşmaz; gerekirse önce onların doğrulanması beklenmeli.

drop trigger if exists on_auth_user_email_confirmed on auth.users;
drop function if exists public.handle_user_email_confirmed();

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_code   text := upper(trim(new.raw_user_meta_data ->> 'invite_code'));
  v_name   text := trim(new.raw_user_meta_data ->> 'full_name');
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

  insert into public.profiles (id, full_name, role, org_id, kvkk_consent_at)
  values (
    new.id,
    v_name,
    v_invite.target_role,
    v_invite.org_id,
    case when (new.raw_user_meta_data ->> 'kvkk_consent')::boolean then now() end
  );

  if v_invite.target_role = 'student' then
    insert into public.coach_students (coach_id, student_id, org_id)
    values (v_invite.coach_id, new.id, v_invite.org_id);
  elsif v_invite.target_role = 'parent' then
    insert into public.parent_students (parent_id, student_id)
    values (new.id, v_invite.student_id);
  end if;

  update public.invite_codes
  set used_count = used_count + 1
  where code = v_code;

  return new;
end;
$$;

drop function if exists public.apply_signup_invite(uuid, jsonb, boolean);
