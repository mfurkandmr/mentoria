-- =====================================================================
-- Başarı sıralaması (kurum içi, deneme netine göre)
--
--  * organizations.success_ranking_enabled: müdür açar/kapatır
--    (set_success_ranking). Kapalıyken öğrenciler sıralamayı görmez.
--  * Puan: öğrencinin o türdeki son 5 denemesinin ortalama toplam neti
--    (en az 1 deneme). TYT ve AYT ayrı sıralanır; AYT alan alan (SAY/EA/
--    SOZ/DIL), çünkü netler farklı ölçeklerde.
--  * Ödüller TYT sıralamasından ve yalnızca sıralama açıkken gelir; öğrenci
--    sırasını kaybedince ödül de gider (kalıcı açılmaz):
--      1.      → kral tacı (+ ilk 3 ödülü)
--      1–3.    → altın arı kanatları
--      4–5.    → gümüş arı kanatları
--    reward_rank = TYT sırası (1–5) ya da null. Uygulama hangi katmanın
--    çizileceğine buna bakarak karar verir; avatar JSON'u değişmez.
--  * Yalnızca ad + soyadın baş harfi ve avatar JSON'u döner (KVKK).
--
-- Geri almak için: supabase/rollbacks/20261017200000_success_ranking.down.sql
-- =====================================================================

alter table public.organizations
  add column success_ranking_enabled boolean not null default false;

-- Sıralamada görünen ad: "Elif Yılmaz" → "Elif Y."
create or replace function public.leaderboard_name(p_full_name text)
returns text
language sql immutable set search_path = ''
as $$
  select split_part(trim(p_full_name), ' ', 1)
    || coalesce(' ' || nullif(left(regexp_replace(trim(p_full_name), '^.*\s', ''), 1), '')
                || '.', '')
$$;

-- Bir kurumdaki öğrencilerin puanları ve sıraları (yetki kontrolü YOK;
-- yalnızca aşağıdaki fonksiyonlar çağırır).
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

-- Bir dershanedeki ödüllü öğrenciler (sıralaması açık kurumlarda TYT ilk 5).
create or replace function public.success_rewards(p_tenant uuid)
returns table (student_id uuid, reward_rank int)
language sql stable security definer set search_path = ''
as $$
  select s.student_id, s.rank
  from public.organizations o
  cross join lateral public.success_scores(o.id, 'TYT', null) s
  where o.tenant_id = p_tenant and o.success_ranking_enabled and s.rank <= 5
$$;

-- Müdür kendi kurumunda sıralamayı açar/kapatır.
create or replace function public.set_success_ranking(p_enabled boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if public.my_role() <> 'admin' or public.my_org() is null
     or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  update public.organizations
  set success_ranking_enabled = coalesce(p_enabled, false)
  where id = public.my_org();
end;
$$;

-- Giriş yapan kullanıcı için: sıralama açık mı, öğrenciyse ödülü ve TYT sırası.
create or replace function public.my_success_status()
returns table (enabled boolean, reward_rank int, tyt_rank int, tyt_avg_net numeric)
language sql stable security definer set search_path = ''
as $$
  with o as (
    select org.id, org.success_ranking_enabled as on_
    from public.organizations org
    where org.id = public.my_org() and public.my_tenant_active()
  ), me as (
    select s.rank, s.avg_net
    from o cross join lateral public.success_scores(o.id, 'TYT', null) s
    where o.on_ and s.student_id = auth.uid() and public.my_role() = 'student'
  )
  select coalesce((select on_ from o), false),
         (select me.rank from me where me.rank <= 5),
         (select me.rank from me),
         (select me.avg_net from me)
$$;

-- Sıralama listesi (sayfalı). Öğrenci ve koç yalnızca sıralama açıkken
-- görür; müdür kapalıyken de önizleyebilir.
create or replace function public.success_leaderboard(
  p_exam_type text,
  p_field     text default null,
  p_limit     int  default 20,
  p_offset    int  default 0)
returns table (
  rank         int,
  student_id   uuid,
  display_name text,
  avatar       jsonb,
  avg_net      numeric,
  exam_count   int,
  reward_rank  int,
  is_me        boolean
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_org     uuid := public.my_org();
  v_role    text := public.my_role()::text;
  v_enabled boolean;
begin
  if p_exam_type not in ('TYT', 'AYT')
     or (p_exam_type = 'AYT' and coalesce(p_field, '') not in ('SAY', 'EA', 'SOZ', 'DIL')) then
    raise exception 'INVALID_RANKING';
  end if;
  if v_org is null or not public.my_tenant_active()
     or v_role not in ('student', 'coach', 'admin') then
    raise exception 'NOT_ALLOWED';
  end if;
  select o.success_ranking_enabled into v_enabled
  from public.organizations o where o.id = v_org;
  if not v_enabled and v_role <> 'admin' then
    raise exception 'RANKING_DISABLED';
  end if;

  return query
  select s.rank, p.id, public.leaderboard_name(p.full_name), p.avatar,
         s.avg_net, s.exam_count,
         case when v_enabled then w.rank end,
         p.id = auth.uid()
  from public.success_scores(v_org, p_exam_type, p_field) s
  join public.profiles p on p.id = s.student_id
  left join public.success_scores(v_org, 'TYT', null) w
    on w.student_id = s.student_id and w.rank <= 5
  order by s.rank, p.full_name
  limit least(greatest(p_limit, 1), 50)
  offset greatest(p_offset, 0);
end;
$$;

-- Haftalık soru sıralaması: ödüllü avatarlar orada da görünsün diye
-- reward_rank kolonu eklendi (dönüş tipi değiştiği için yeniden oluşturuldu).
drop function if exists public.avatar_leaderboard(int, int);
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

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
revoke execute on function public.leaderboard_name(text)                 from public, anon, authenticated;
revoke execute on function public.success_scores(uuid, text, text)       from public, anon, authenticated;
revoke execute on function public.success_rewards(uuid)                  from public, anon, authenticated;
revoke execute on function public.set_success_ranking(boolean)           from public, anon;
grant  execute on function public.set_success_ranking(boolean)           to authenticated;
revoke execute on function public.my_success_status()                    from public, anon;
grant  execute on function public.my_success_status()                    to authenticated;
revoke execute on function public.success_leaderboard(text, text, int, int) from public, anon;
grant  execute on function public.success_leaderboard(text, text, int, int) to authenticated;
revoke execute on function public.avatar_leaderboard(int, int)           from public, anon;
grant  execute on function public.avatar_leaderboard(int, int)           to authenticated;
