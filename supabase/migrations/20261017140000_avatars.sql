-- =====================================================================
-- Öğrenci avatarı (Bitmoji tarzı)
--
--  * profiles.avatar: küçük JSON, ör. {"hair": 3, "skin": 7, "outfit": 10,
--    "accessory": 15}. Değerler avatar_items.id. Görsel üretilmez/yüklenmez;
--    parçalar uygulamanın içindeki asset'lerden üst üste çizilir.
--  * avatar_items: parça kataloğu. Açılma koşulu (unlock_rule) burada tutulur,
--    uygulamaya gömülmez. Yeni parça = asset dosyası + bu tabloya bir satır.
--      {"type": "free"}
--      {"type": "streak", "days": 7}                  en uzun çalışma serisi
--      {"type": "net", "exam_type": "TYT", "value": 60} bir denemede toplam net
--      {"type": "badge", "badge": "questions_1000"}   uygulamadaki rozetler
--  * user_unlocked_items: öğrencinin açtığı parçalar. Yalnızca sunucu yazar
--    (claim_avatar_unlocks); istemci kilitli parçayı kuşanamaz (guard_avatar).
--  * Başkasının avatarı yalnızca aynı dershanede ve sıralama fonksiyonuyla
--    (sayfalı) görülür. Hesap silinince profil ve açılan parçalar silinir.
--  * Fotoğraf ya da yüz verisi alınmaz.
--
-- Geri almak için: supabase/rollbacks/20261017140000_avatars.down.sql
-- =====================================================================

create table public.avatar_items (
  id          smallint primary key,
  category    text not null check (category in ('hair', 'skin', 'outfit', 'accessory')),
  asset_name  text not null unique check (asset_name ~ '^[a-z0-9_]{2,40}$'),
  unlock_rule jsonb not null default '{"type": "free"}'
              check (jsonb_typeof(unlock_rule) = 'object' and unlock_rule ? 'type'),
  sort        int not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);
create index on public.avatar_items (category, sort);

create table public.user_unlocked_items (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  item_id     smallint not null references public.avatar_items (id) on delete cascade,
  tenant_id   uuid not null references public.tenants (id),
  unlocked_at timestamptz not null default now(),
  primary key (user_id, item_id)
);
create index on public.user_unlocked_items (item_id);
create index on public.user_unlocked_items (tenant_id);

alter table public.profiles add column avatar jsonb;

-- Başlangıç seti: 5 saç, 4 ten, 5 kıyafet, 3 aksesuar.
insert into public.avatar_items (id, category, asset_name, unlock_rule, sort) values
  (1,  'hair',      'hair_short',      '{"type": "free"}', 1),
  (2,  'hair',      'hair_curly',      '{"type": "free"}', 2),
  (3,  'hair',      'hair_bun',        '{"type": "free"}', 3),
  (4,  'hair',      'hair_spiky',      '{"type": "streak", "days": 3}', 4),
  (5,  'hair',      'hair_rainbow',    '{"type": "net", "exam_type": "TYT", "value": 60}', 5),
  (6,  'skin',      'skin_light',      '{"type": "free"}', 1),
  (7,  'skin',      'skin_tan',        '{"type": "free"}', 2),
  (8,  'skin',      'skin_brown',      '{"type": "free"}', 3),
  (9,  'skin',      'skin_dark',       '{"type": "free"}', 4),
  (10, 'outfit',    'outfit_tee',      '{"type": "free"}', 1),
  (11, 'outfit',    'outfit_hoodie',   '{"type": "free"}', 2),
  (12, 'outfit',    'outfit_varsity',  '{"type": "badge", "badge": "first_exam"}', 3),
  (13, 'outfit',    'outfit_bee',      '{"type": "streak", "days": 7}', 4),
  (14, 'outfit',    'outfit_cape',     '{"type": "badge", "badge": "questions_1000"}', 5),
  (15, 'accessory', 'acc_glasses',     '{"type": "free"}', 1),
  (16, 'accessory', 'acc_headphones',  '{"type": "badge", "badge": "focus_master"}', 2),
  (17, 'accessory', 'acc_crown',       '{"type": "streak", "days": 30}', 3);

-- ---------------------------------------------------------------------
-- Başarı ölçüleri (kural değerlendirmesi için)
-- ---------------------------------------------------------------------

-- En uzun art arda çalışma serisi (soru kaydı ya da çalışma oturumu olan günler).
create or replace function public.student_best_streak(p_user uuid)
returns int
language sql stable security definer set search_path = ''
as $$
  with d as (
    select logged_on as day from public.question_logs
    where student_id = p_user and correct + wrong + blank > 0
    union
    select (started_at at time zone 'Europe/Istanbul')::date
    from public.study_sessions where student_id = p_user
  ), g as (
    select day - (row_number() over (order by day))::int as grp from d
  )
  select coalesce(max(n), 0)::int from (select count(*) n from g group by grp) s
$$;

create or replace function public.student_best_net(p_user uuid, p_exam_type text)
returns numeric
language sql stable security definer set search_path = ''
as $$
  select coalesce(max(total), 0) from (
    select sum(r.net) total
    from public.exams e
    join public.exam_subject_results r on r.exam_id = e.id
    where e.student_id = p_user
      and (p_exam_type is null or e.exam_type::text = upper(p_exam_type))
    group by e.id
  ) s
$$;

-- Uygulamadaki rozetlerle aynı anahtarlar ve eşikler.
create or replace function public.student_has_badge(p_user uuid, p_badge text)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_questions int;
  v_minutes   int;
begin
  select coalesce(sum(correct + wrong + blank), 0) into v_questions
  from public.question_logs where student_id = p_user;

  return case p_badge
    when 'first_step'       then v_questions >= 1
    when 'questions_100'    then v_questions >= 100
    when 'questions_1000'   then v_questions >= 1000
    when 'question_machine' then v_questions >= 5000
    when 'streak_3'         then public.student_best_streak(p_user) >= 3
    when 'streak_7'         then public.student_best_streak(p_user) >= 7
    when 'streak_30'        then public.student_best_streak(p_user) >= 30
    when 'first_exam'       then exists (select 1 from public.exams where student_id = p_user)
    when 'focus_master'     then (select coalesce(sum(duration_sec), 0) / 60
                                  from public.study_sessions where student_id = p_user) >= 600
    when 'topic_hunter'     then (select count(*) from public.topic_progress
                                  where student_id = p_user and status = 'done') >= 10
    else false
  end;
end;
$$;

create or replace function public.avatar_rule_met(p_user uuid, p_rule jsonb)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
begin
  return case p_rule ->> 'type'
    when 'free'   then true
    when 'streak' then public.student_best_streak(p_user) >= coalesce((p_rule ->> 'days')::int, 1)
    when 'net'    then public.student_best_net(p_user, p_rule ->> 'exam_type')
                         >= coalesce((p_rule ->> 'value')::numeric, 0)
    when 'badge'  then public.student_has_badge(p_user, p_rule ->> 'badge')
    else false   -- bilinmeyen kural: güvenli tarafta kal
  end;
end;
$$;

-- Hak edilen parçaları açar; YENİ açılanların id'lerini döndürür.
-- Uygulama avatar editörü ve ana sayfa açılırken bir kez çağırır.
create or replace function public.claim_avatar_unlocks()
returns smallint[]
language plpgsql security definer set search_path = ''
as $$
declare
  v_me     public.profiles%rowtype;
  v_new    smallint[];
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found or v_me.role <> 'student' or v_me.tenant_id is null then
    return '{}';
  end if;

  with ins as (
    insert into public.user_unlocked_items (user_id, item_id, tenant_id)
    select v_me.id, i.id, v_me.tenant_id
    from public.avatar_items i
    where i.is_active
      and i.unlock_rule ->> 'type' <> 'free'
      and not exists (select 1 from public.user_unlocked_items u
                      where u.user_id = v_me.id and u.item_id = i.id)
      and public.avatar_rule_met(v_me.id, i.unlock_rule)
    on conflict do nothing
    returning item_id
  )
  select coalesce(array_agg(item_id order by item_id), '{}') into v_new from ins;
  return v_new;
end;
$$;

-- ---------------------------------------------------------------------
-- Avatar doğrulama: yalnızca öğrenci, kendi avatarı, geçerli ve açılmış parça
-- ---------------------------------------------------------------------
create or replace function public.guard_avatar()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  k text;
  v jsonb;
  v_item public.avatar_items%rowtype;
begin
  if new.avatar is not distinct from old.avatar then
    return new;
  end if;
  if auth.uid() is not null and auth.uid() <> new.id then
    raise exception 'AVATAR_NOT_OWNER';
  end if;
  if new.avatar is null then
    return new;
  end if;
  if new.role <> 'student' then
    raise exception 'AVATAR_STUDENTS_ONLY';
  end if;
  if jsonb_typeof(new.avatar) <> 'object' or pg_column_size(new.avatar) > 200 then
    raise exception 'AVATAR_INVALID';
  end if;

  for k, v in select * from jsonb_each(new.avatar) loop
    if k not in ('hair', 'skin', 'outfit', 'accessory') or jsonb_typeof(v) <> 'number' then
      raise exception 'AVATAR_INVALID';
    end if;
    select * into v_item from public.avatar_items
    where id = (v #>> '{}')::smallint and category = k and is_active;
    if not found then
      raise exception 'AVATAR_INVALID';
    end if;
    if v_item.unlock_rule ->> 'type' <> 'free' and not exists (
      select 1 from public.user_unlocked_items
      where user_id = new.id and item_id = v_item.id
    ) then
      raise exception 'AVATAR_ITEM_LOCKED';
    end if;
  end loop;
  return new;
end;
$$;

create trigger guard_avatar
  before update of avatar on public.profiles
  for each row execute function public.guard_avatar();

-- Öğrenci kendi profilinde avatar kolonunu güncelleyebilir
-- ("update own profile" politikası zaten yalnızca kendi satırına izin verir).
grant update (avatar) on public.profiles to authenticated;

-- ---------------------------------------------------------------------
-- Haftalık sıralama (aynı dershane, sayfalı, yalnızca avatar JSON'u)
-- ---------------------------------------------------------------------
create or replace function public.avatar_leaderboard(p_limit int default 20, p_offset int default 0)
returns table (
  rank           int,
  student_id     uuid,
  display_name   text,
  avatar         jsonb,
  week_questions int,
  is_me          boolean
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
  select r.rank, r.id,
         -- KVKK: yalnızca ad ve soyadın baş harfi
         split_part(trim(r.full_name), ' ', 1)
           || coalesce(' ' || nullif(left(regexp_replace(trim(r.full_name), '^.*\s', ''), 1), '')
                       || '.', ''),
         r.avatar, r.week_questions, r.id = auth.uid()
  from ranked r
  order by r.rank, r.full_name
  limit least(greatest(p_limit, 1), 50)
  offset greatest(p_offset, 0)
$$;

-- ---------------------------------------------------------------------
-- RLS ve yetkiler
-- ---------------------------------------------------------------------
alter table public.avatar_items        enable row level security;
alter table public.user_unlocked_items enable row level security;

-- Katalog herkese (giriş yapmış) açık, yazma yalnızca SQL ile.
create policy "read avatar items" on public.avatar_items
  for select to authenticated using (true);
revoke insert, update, delete on public.avatar_items from anon, authenticated;

create policy "read own unlocks" on public.user_unlocked_items
  for select to authenticated using (user_id = (select auth.uid()));
create policy "tenant isolation" on public.user_unlocked_items as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()));
revoke insert, update, delete on public.user_unlocked_items from anon, authenticated;

revoke execute on function public.student_best_streak(uuid)       from public, anon, authenticated;
revoke execute on function public.student_best_net(uuid, text)    from public, anon, authenticated;
revoke execute on function public.student_has_badge(uuid, text)   from public, anon, authenticated;
revoke execute on function public.avatar_rule_met(uuid, jsonb)    from public, anon, authenticated;
revoke execute on function public.guard_avatar()                  from public, anon, authenticated;
revoke execute on function public.claim_avatar_unlocks()          from public, anon;
grant  execute on function public.claim_avatar_unlocks()          to authenticated;
revoke execute on function public.avatar_leaderboard(int, int)    from public, anon;
grant  execute on function public.avatar_leaderboard(int, int)    to authenticated;
