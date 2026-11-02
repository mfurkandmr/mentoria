-- =====================================================================
-- KVKK: kayıtta onay zorunlu, metin güncellenince yeniden onay
-- ---------------------------------------------------------------------
--  * apply_signup_invite: kvkk_consent = true gelmeyen kayıt KVKK_REQUIRED
--    ile reddedilir. Önceden yalnızca uygulamadaki zorunlu kutu vardı;
--    doğrudan API çağrısıyla onaysız hesap açılabiliyordu.
--  * set_consent: aynı rıza yalnızca aynı sürümle tekrar yazılmaz. Önceden
--    Aydınlatma Metni bir kez onaylandıysa yeni sürümün onayı hiç
--    kaydedilmiyordu.
--  * consent_status: 'privacy_version' = onaylanan son metin sürümü.
--    Uygulama bunu legalVersion ile karşılaştırır, farklıysa girişte
--    yeniden onay ister. Kişi kendi durumunu her rolde okuyabilir.
--
-- Geri almak için: supabase/rollbacks/20261102100000_signup_consent_required.down.sql
-- =====================================================================

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
  -- KVKK: Kullanım Koşulları + Aydınlatma Metni teyidi olmadan hesap açılmaz
  -- (uygulama kutuyu zorunlu tutar; burada doğrudan API çağrısı da reddedilir).
  if (p_meta ->> 'kvkk_consent') is distinct from 'true' then
    raise exception 'KVKK_REQUIRED';
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

create or replace function public.set_consent(
  p_kind text,
  p_granted boolean,
  p_version text,
  p_student uuid default null
) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_me     public.profiles%rowtype;
  v_target uuid;
  v_source text;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if p_student is null or p_student = v_me.id then
    v_target := v_me.id;
    v_source := 'self';
    if p_kind not in ('privacy_notice', 'ranking', 'parent_view') then
      raise exception 'INVALID_CONSENT';
    end if;
    if p_kind in ('ranking', 'parent_view') and v_me.role <> 'student' then
      raise exception 'INVALID_CONSENT';
    end if;
    -- 18 altında veli zaten veli onayı sürecinin parçası.
    if p_kind = 'parent_view' and public.is_minor(v_me.id) then
      raise exception 'MINOR_PARENT_VIEW';
    end if;
  else
    if not exists (
      select 1 from public.parent_students
      where parent_id = v_me.id and student_id = p_student
    ) then
      raise exception 'NOT_ALLOWED';
    end if;
    if p_kind not in ('guardian_approval', 'ranking') then
      raise exception 'INVALID_CONSENT';
    end if;
    v_target := p_student;
    v_source := 'parent';
  end if;

  -- Aynı durum aynı metin sürümüyle tekrar yazılmasın. Sürüm değiştiyse
  -- (ör. güncellenen Aydınlatma Metni yeniden onaylandı) yeni satır yazılır.
  if exists (
    select 1 from (
      select c.granted, c.version from public.consents c
      where c.user_id = v_target and c.kind = p_kind
      order by c.created_at desc, c.id desc
      limit 1
    ) last
    where last.granted = p_granted
      and last.version = coalesce(nullif(trim(p_version), ''), '1.0')
  ) then
    return;
  end if;

  insert into public.consents (user_id, kind, granted, version, source, given_by)
  values (v_target, p_kind, p_granted, coalesce(nullif(trim(p_version), ''), '1.0'),
          v_source, v_me.id);

  -- Yetişkin öğrenci veli iznini geri çekti: veli artık göremez.
  if p_kind = 'parent_view' and not p_granted then
    delete from public.parent_students where student_id = v_target;
  end if;

  -- Veli, çocuğunun kullanım onayını geri çekti: hesap silme talebi açılır
  -- (koç/müdür sonuçlandırır; 29 günde sonuçlanmazsa otomatik silinir).
  if p_kind = 'guardian_approval' and not p_granted then
    insert into public.account_deletion_requests (student_id)
    values (v_target)
    on conflict (student_id) do nothing;
  end if;
end;
$$;

create or replace function public.consent_status(p_user uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_user uuid := coalesce(p_user, auth.uid());
begin
  if v_user is null
     or (v_user is distinct from auth.uid() and not public.can_view_student(v_user)) then
    raise exception 'NOT_ALLOWED';
  end if;
  return (
    select jsonb_build_object(
      'birth_year', p.birth_year,
      'minor', public.is_minor(v_user),
      'privacy_notice', public.has_consent(v_user, 'privacy_notice'),
      -- Onaylanan en son metin sürümü (geri çekilmişse ya da hiç yoksa null).
      'privacy_version', (
        select case when c.granted then c.version end from public.consents c
        where c.user_id = v_user and c.kind = 'privacy_notice'
        order by c.created_at desc, c.id desc limit 1),
      'ranking', public.has_consent(v_user, 'ranking'),
      'parent_view', public.has_consent(v_user, 'parent_view'),
      'guardian_approval', public.has_consent(v_user, 'guardian_approval'),
      'guardian_source', (
        select c.source from public.consents c
        where c.user_id = v_user and c.kind = 'guardian_approval' and c.granted
        order by c.created_at desc, c.id desc limit 1),
      'ranking_visible', public.ranking_visible(v_user),
      'has_parent', exists (select 1 from public.parent_students s where s.student_id = v_user),
      'history', coalesce((
        select jsonb_agg(jsonb_build_object(
            'kind', c.kind, 'granted', c.granted, 'version', c.version,
            'source', c.source, 'at', c.created_at)
          order by c.created_at desc)
        from public.consents c where c.user_id = v_user), '[]'::jsonb)
    )
    from public.profiles p where p.id = v_user
  );
end;
$$;
