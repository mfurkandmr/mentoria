-- KVKK: rıza kayıtları, doğum yılı, veli onayı, verilerimi indir, silme
-- talebinin süresinde sonuçlanması, hata defteri fotoğraflarının temizliği.
-- Metinler: docs/kvkk/. Geri almak için:
-- supabase/rollbacks/20261019150000_kvkk_consents.down.sql
--
--   1. profiles.birth_year + is_minor(): yaşı yalnızca doğum yılından
--      biliyoruz; o yıl 18'ini dolduranlar da yıl bitene kadar küçük sayılır
--      (güvenli taraf). Doğum yılı yoksa küçük sayılır.
--   2. consents: her onay / geri çekme ayrı satır (değiştirilmez kayıt).
--      Güncel durum = türüne göre son satır. Türler:
--        privacy_notice    aydınlatma metnini okudum (rıza değil, teyit)
--        ranking           başarı sıralaması ve avatar liderliğinde görünmek
--        parent_view       (18+) davet ettiğim velinin verilerimi görmesi
--        guardian_approval (18-) veli onayı: veliden ya da kurum beyanından
--   3. Sıralamalarda yalnızca rıza verenler (18 altında ayrıca veli onayı).
--   4. Kurum beyanı: davet oluştururken "veli onayını kurumumuz aldı".
--   5. export_my_data(): KVKK md. 11, verilerimi indir.
--   6. Öğrencinin silme talebi 29 gün içinde koç/müdür tarafından
--      sonuçlanmazsa gece otomatik silinir (KVKK 30 gün cevap süresi).
--   7. Hata defteri kartı (ya da hesap) silinince fotoğraf, temizlik
--      kuyruğuna girer; storage-cleanup Edge Function depodan siler
--      (Supabase depo satırlarının SQL ile silinmesine izin vermiyor).

-- 1. Doğum yılı ---------------------------------------------------------------
alter table public.profiles
  add column birth_year smallint
  check (birth_year between 1940 and 2030);

create or replace function public.is_minor(p_user uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select p.birth_year >= extract(year from current_date)::int - 18
     from public.profiles p where p.id = p_user),
    true)
$$;
revoke all on function public.is_minor(uuid) from public, anon;
grant execute on function public.is_minor(uuid) to authenticated;

-- Doğum yılı bir kez kişinin kendisince girilir; sonra koç/müdür düzeltir.
create or replace function public.set_birth_year(p_year int, p_user uuid default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_target uuid := coalesce(p_user, auth.uid());
  v_current smallint;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_year < 1940 or p_year > extract(year from current_date)::int - 10 then
    raise exception 'INVALID_BIRTH_YEAR';
  end if;
  select birth_year into v_current from public.profiles where id = v_target;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if v_target = auth.uid() then
    if v_current is not null then
      raise exception 'BIRTH_YEAR_LOCKED';
    end if;
  elsif not public.can_manage_student(v_target) then
    raise exception 'NOT_ALLOWED';
  end if;
  update public.profiles set birth_year = p_year where id = v_target;
end;
$$;
revoke all on function public.set_birth_year(int, uuid) from public, anon;
grant execute on function public.set_birth_year(int, uuid) to authenticated;

-- 2. Rıza kayıtları -------------------------------------------------------------
create table public.consents (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in
               ('privacy_notice', 'ranking', 'parent_view', 'guardian_approval')),
  granted    boolean not null,
  version    text not null check (length(version) between 1 and 20),
  -- Kim verdi: kendisi, velisi ya da kurum (beyan eden yönetici/koç).
  source     text not null check (source in ('self', 'parent', 'institution')),
  given_by   uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index consents_user_kind_idx on public.consents (user_id, kind, created_at desc);
create index consents_given_by_idx on public.consents (given_by);
alter table public.consents enable row level security;
-- Okuma: kendisi, velisi, koçu, kurum müdürü. Yazma yalnızca fonksiyonlarla.
create policy "view consents" on public.consents
  for select to authenticated using (public.can_view_student(user_id));
revoke insert, update, delete on public.consents from anon, authenticated;

-- Eski kayıt ekranındaki birleşik kutu ("okudum, onay veriyorum") işaretlenmiş
-- hesaplar: aydınlatma teyidi sürüm '0' olarak geçmişe aktarılır.
insert into public.consents (user_id, kind, granted, version, source, given_by, created_at)
select p.id, 'privacy_notice', true, '0', 'self', p.id, p.kvkk_consent_at
from public.profiles p
where p.kvkk_consent_at is not null;

create or replace function public.has_consent(p_user uuid, p_kind text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce((
    select c.granted from public.consents c
    where c.user_id = p_user and c.kind = p_kind
    order by c.created_at desc, c.id desc
    limit 1), false)
$$;
revoke all on function public.has_consent(uuid, text) from public, anon;
grant execute on function public.has_consent(uuid, text) to authenticated;

-- Sıralamalarda görünür mü: rıza + (18 altında) veli onayı.
create or replace function public.ranking_visible(p_user uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select public.has_consent(p_user, 'ranking')
     and (not public.is_minor(p_user)
          or public.has_consent(p_user, 'guardian_approval'))
$$;
revoke all on function public.ranking_visible(uuid) from public, anon;
grant execute on function public.ranking_visible(uuid) to authenticated;

-- Rıza ver / geri çek.
--   p_student boş: kendi rızam (privacy_notice, ranking, parent_view).
--   p_student dolu: veli olarak çocuğum için (guardian_approval, ranking).
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

  -- Aynı durum tekrar yazılmasın.
  if public.has_consent(v_target, p_kind) = p_granted
     and exists (select 1 from public.consents
                 where user_id = v_target and kind = p_kind) then
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
revoke all on function public.set_consent(text, boolean, text, uuid) from public, anon;
grant execute on function public.set_consent(text, boolean, text, uuid) to authenticated;

-- Ekranlar için tek bakışta durum (kendim ya da görebildiğim öğrenci).
create or replace function public.consent_status(p_user uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_user uuid := coalesce(p_user, auth.uid());
begin
  if v_user is null or not public.can_view_student(v_user) then
    raise exception 'NOT_ALLOWED';
  end if;
  return (
    select jsonb_build_object(
      'birth_year', p.birth_year,
      'minor', public.is_minor(v_user),
      'privacy_notice', public.has_consent(v_user, 'privacy_notice'),
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
revoke all on function public.consent_status(uuid) from public, anon;
grant execute on function public.consent_status(uuid) to authenticated;

-- 3. Sıralamalarda yalnızca rıza verenler -------------------------------------
create or replace function public.success_scores(p_org uuid, p_exam_type text, p_field text)
returns table (student_id uuid, avg_net numeric, exam_count integer, rank integer)
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
      -- KVKK: yalnızca sıralamada görünmeye rıza verenler.
      and public.ranking_visible(p.id)
  ), s as (
    select e.student_id, round(avg(e.total), 2) as avg_net, count(*)::int as exam_count
    from e where e.rn <= 5
    group by e.student_id
  )
  select s.student_id, s.avg_net, s.exam_count,
         rank() over (order by s.avg_net desc)::int
  from s
$$;

create or replace function public.avatar_leaderboard(p_limit integer default 20, p_offset integer default 0)
returns table (rank integer, student_id uuid, display_name text, avatar jsonb,
               week_questions integer, is_me boolean, reward_rank integer)
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
      -- KVKK: yalnızca sıralamada görünmeye rıza verenler.
      and public.ranking_visible(p.id)
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

-- 4. Davet: kurum beyanı, check_invite'ta çocuğun yaşı, kayıtta rızalar --------
alter table public.invite_codes
  add column guardian_statement_at timestamptz;

drop function if exists public.create_invite(public.user_role, uuid, integer);
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
revoke execute on function public.create_invite(public.user_role, uuid, integer, boolean) from public, anon;
grant execute on function public.create_invite(public.user_role, uuid, integer, boolean) to authenticated;

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

-- Kayıt: doğum yılı ve rızalar da yazılır. Metadata (uygulamadan):
--   kvkk_consent: true, privacy_version: '1.0', birth_year: 2009,
--   consents: {"ranking": true}                 (öğrenci)
--   guardian_approval: true, child_ranking: true (veli)
create or replace function public.apply_signup_invite(p_user_id uuid, p_meta jsonb, p_apply boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_code    text := upper(trim(p_meta ->> 'invite_code'));
  v_name    text := trim(p_meta ->> 'full_name');
  v_version text := coalesce(nullif(trim(p_meta ->> 'privacy_version'), ''), '0');
  v_birth   int;
  v_invite  public.invite_codes%rowtype;
  v_seats   int;
  v_used    int;
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

  update public.invite_codes
  set used_count = used_count + 1
  where code = v_code;
end;
$$;
revoke all on function public.apply_signup_invite(uuid, jsonb, boolean)
  from public, anon, authenticated;

-- 5. Verilerimi indir (KVKK md. 11) -------------------------------------------
-- SECURITY INVOKER: yalnızca RLS'in bana gösterdiği satırlar. E-posta adresi
-- (auth.users okunamaz) uygulama tarafından oturumdan eklenir.
create or replace function public.export_my_data()
returns jsonb
language sql stable security invoker set search_path = ''
as $$
  with me as (select auth.uid() as id)
  select jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'tenant_id' from public.profiles p, me where p.id = me.id),
    'consents', coalesce((select jsonb_agg(to_jsonb(c) - 'id' order by c.created_at)
                 from public.consents c, me where c.user_id = me.id), '[]'),
    'goals', (select to_jsonb(g) - 'tenant_id' from public.goals g, me where g.student_id = me.id),
    'exams', coalesce((select jsonb_agg((to_jsonb(e) - 'tenant_id') || jsonb_build_object(
                 'results', coalesce((select jsonb_agg(jsonb_build_object(
                     'subject', s.code, 'correct', r.correct, 'wrong', r.wrong,
                     'blank', r.blank, 'net', r.net))
                   from public.exam_subject_results r
                   join public.subjects s on s.id = r.subject_id
                   where r.exam_id = e.id), '[]'))
               order by e.taken_on)
               from public.exams e, me where e.student_id = me.id), '[]'),
    'question_logs', coalesce((select jsonb_agg(to_jsonb(q) - 'tenant_id' order by q.logged_on)
                 from public.question_logs q, me where q.student_id = me.id), '[]'),
    'study_sessions', coalesce((select jsonb_agg(to_jsonb(s) - 'tenant_id' order by s.started_at)
                 from public.study_sessions s, me where s.student_id = me.id), '[]'),
    'topic_progress', coalesce((select jsonb_agg(to_jsonb(t) - 'tenant_id')
                 from public.topic_progress t, me where t.student_id = me.id), '[]'),
    'mistake_cards', coalesce((select jsonb_agg(to_jsonb(m) - 'tenant_id' order by m.created_at)
                 from public.mistake_cards m, me where m.student_id = me.id), '[]'),
    'plan_items', coalesce((select jsonb_agg(to_jsonb(pl) - 'tenant_id' order by pl.day)
                 from public.plan_items pl, me where pl.student_id = me.id), '[]'),
    'tasks', coalesce((select jsonb_agg(to_jsonb(t) - 'tenant_id' order by t.created_at)
                 from public.tasks t, me where t.student_id = me.id), '[]'),
    'coach_notes', coalesce((select jsonb_agg(to_jsonb(n) - 'tenant_id' order by n.created_at)
                 from public.coach_notes n, me where n.student_id = me.id), '[]'),
    'assignments', coalesce((select jsonb_agg((to_jsonb(a) - 'tenant_id') || jsonb_build_object(
                 'items', coalesce((select jsonb_agg(to_jsonb(i) - 'tenant_id')
                   from public.assignment_items i where i.assignment_id = a.id), '[]'))
               order by a.created_at)
               from public.assignments a, me where a.student_id = me.id), '[]'),
    'meetings', coalesce((select jsonb_agg(to_jsonb(ms) - 'tenant_id')
                 from public.meeting_schedules ms, me where ms.student_id = me.id), '[]'),
    'daily_answers', coalesce((select jsonb_agg(to_jsonb(d) - 'tenant_id')
                 from public.daily_answers d, me where d.student_id = me.id), '[]'),
    'practice_answers', coalesce((select jsonb_agg(to_jsonb(pa) - 'tenant_id')
                 from public.practice_answers pa, me where pa.student_id = me.id), '[]'),
    'notifications', coalesce((select jsonb_agg(to_jsonb(no) - 'tenant_id' order by no.created_at)
                 from public.notifications no, me where no.user_id = me.id), '[]')
  )
$$;
revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- 6. Süresinde sonuçlanmayan silme talepleri -----------------------------------
create or replace function public.process_overdue_deletion_requests()
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_n int;
begin
  delete from auth.users
  where id in (
    select r.student_id from public.account_deletion_requests r
    where r.requested_at < now() - interval '29 days'
  );
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.process_overdue_deletion_requests() from public, anon, authenticated;

-- 7. Hata defteri fotoğraflarının temizliği ------------------------------------
create table public.storage_cleanup (
  bucket     text not null,
  path       text not null,
  created_at timestamptz not null default now(),
  primary key (bucket, path)
);
alter table public.storage_cleanup enable row level security;
-- Politika yok: yalnızca tetikleyici ve service role (Edge Function) dokunur.
revoke all on public.storage_cleanup from anon, authenticated;

create or replace function public.queue_mistake_photo_cleanup()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.photo_path is not null then
    insert into public.storage_cleanup (bucket, path)
    values ('mistake-photos', old.photo_path)
    on conflict do nothing;
  end if;
  return old;
end;
$$;
revoke execute on function public.queue_mistake_photo_cleanup() from public, anon, authenticated;

create trigger queue_mistake_photo_cleanup
  after delete on public.mistake_cards
  for each row execute function public.queue_mistake_photo_cleanup();

-- Kuyrukta iş varsa storage-cleanup Edge Function'ını çağırır (send-push ile
-- aynı Vault ayarları; adres send-push'unkinden türetilir).
create or replace function public.kick_storage_cleanup()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_url    text;
  v_secret text;
begin
  if not exists (select 1 from public.storage_cleanup) then
    return;
  end if;
  select replace(decrypted_secret, '/send-push', '/storage-cleanup') into v_url
  from vault.decrypted_secrets where name = 'push_function_url';
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_url is null or v_secret is null then
    return;
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000);
exception when others then
  raise warning 'kick_storage_cleanup: %', sqlerrm;
end;
$$;
revoke execute on function public.kick_storage_cleanup() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    -- 03.00 Türkiye saati.
    perform cron.schedule('overdue-deletion-requests', '0 0 * * *',
      'select public.process_overdue_deletion_requests()');
    perform cron.schedule('storage-cleanup', '*/10 * * * *',
      'select public.kick_storage_cleanup()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); zamanlanmadı';
  end if;
end;
$$;
