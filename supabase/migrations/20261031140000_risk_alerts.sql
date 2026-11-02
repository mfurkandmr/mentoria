-- =====================================================================
-- Risk erken uyarısı
-- ---------------------------------------------------------------------
-- Devamsızlık, net düşüşü ve ödev tamamlamayı tek skorda (0-100) birleştirir;
-- rehber öğretmene her pazartesi "bu öğrencilerle konuş" listesi düşer.
-- Veri weekly_summary_data ile aynı (son 7 gün, TR).
--
-- Skor (yüksek = riskli):
--   devam   en çok 50: çalışmadığı her gün 5 puan (7 gün = 35) + kaçırılan her
--           koç görüşmesi 7,5 puan (en çok 2 görüşme = 15)
--   net     en çok 30: son deneme (son 30 gün içinde) aynı türdeki bir
--           öncekinden düşükse, her 1 net düşüş 3 puan (10 net = 30)
--   ödev    en çok 20: bu hafta teslimli ödevde yapılmayan oran × 20
-- Listeye 30 ve üstü girer; en riskli 7 öğrenci. Yeni kayıt olan (7 günden
-- kısa) öğrenci listeye girmez.
--
--  * my_risk_list(): koç kendi öğrencilerini, müdür kurumundakileri görür.
--  * send_risk_digests(): pazartesi 08:00 (TR), geçen haftaya (pzt-paz) göre
--    her koça tek 'risk_digest' bildirimi (en az 1 riskli öğrenci varsa).
--
-- Geri almak için: supabase/rollbacks/20261031140000_risk_alerts.down.sql
-- =====================================================================

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest'));

-- Haftalık özetten skor ve bileşenleri.
create or replace function public.risk_score(p_s jsonb)
returns jsonb
language sql immutable set search_path = ''
as $$
  with v as (
    select coalesce((p_s ->> 'days')::int, 0) as days,
           least(coalesce((p_s ->> 'meetings_missed')::int, 0), 2) as missed,
           coalesce((p_s ->> 'homework_total')::int, 0) as hw_total,
           coalesce((p_s ->> 'homework_done')::int, 0) as hw_done,
           case
             when p_s ->> 'prev_net' is not null
              and (p_s ->> 'exam_on')::date >= (p_s ->> 'to')::date - 30
             then greatest((p_s ->> 'prev_net')::numeric - (p_s ->> 'last_net')::numeric, 0)
             else 0
           end as drop
  ), parts as (
    select v.*,
           5.0 * (7 - v.days) + 7.5 * v.missed as attendance,
           3.0 * least(v.drop, 10) as net,
           case when v.hw_total > 0
                then 20.0 * (v.hw_total - v.hw_done) / v.hw_total else 0 end as homework
    from v
  )
  select jsonb_build_object(
    'score', least(100, round(attendance + net + homework))::int,
    'attendance', round(attendance)::int,
    'net', round(net)::int,
    'homework', round(homework)::int,
    'net_drop', drop)
  from parts
$$;
revoke all on function public.risk_score(jsonb) from public, anon;
grant execute on function public.risk_score(jsonb) to authenticated;

-- Verilen öğrencilerin skoru (iç fonksiyon; istemci çağıramaz).
create or replace function public.risk_rows(p_students uuid[], p_now timestamptz)
returns table (
  student_id      uuid,
  full_name       text,
  score           int,
  days            int,
  meetings_missed int,
  net_drop        numeric,
  exam_type       text,
  homework_total  int,
  homework_done   int
)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.full_name, (r ->> 'score')::int,
         (w.s ->> 'days')::int, (w.s ->> 'meetings_missed')::int,
         (r ->> 'net_drop')::numeric, w.s ->> 'exam_type',
         (w.s ->> 'homework_total')::int, (w.s ->> 'homework_done')::int
  from public.profiles p
  cross join lateral (select public.weekly_summary_data(p.id, p_now) as s) w
  cross join lateral (select public.risk_score(w.s) as r) k
  where p.id = any(p_students)
    and p.role = 'student'
    and p.created_at < p_now - interval '7 days'
$$;
revoke all on function public.risk_rows(uuid[], timestamptz) from public, anon, authenticated;

-- Koç: kendi öğrencileri; müdür: kurumundaki öğrenciler. Son 7 gün.
create or replace function public.my_risk_list(p_limit int default 7)
returns table (
  student_id      uuid,
  full_name       text,
  score           int,
  days            int,
  meetings_missed int,
  net_drop        numeric,
  exam_type       text,
  homework_total  int,
  homework_done   int
)
language sql stable security definer set search_path = ''
as $$
  select r.*
  from public.risk_rows(
    array(
      select cs.student_id from public.coach_students cs
      where cs.coach_id = auth.uid()
      union
      select s.id from public.profiles s
      where public.my_role() = 'admin' and s.role = 'student'
        and s.org_id = public.my_org()
    ), now()) r
  where public.my_tenant_active() and r.score >= 30
  order by r.score desc, r.full_name
  limit least(greatest(coalesce(p_limit, 7), 1), 50)
$$;
revoke execute on function public.my_risk_list(int) from public, anon;
grant execute on function public.my_risk_list(int) to authenticated;

-- Pazartesi sabahı her koça geçen haftanın listesi (tek bildirim).
create or replace function public.send_risk_digests(p_now timestamptz default now())
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_n int;
begin
  insert into public.notifications (user_id, kind, data)
  select c.id, 'risk_digest',
         jsonb_build_object(
           'count', l.n,
           'names', l.names,
           'route', '/coach')
  from public.profiles c
  join public.tenants t on t.id = c.tenant_id and t.is_active
  left join public.organizations o on o.id = c.org_id
  cross join lateral (
    select count(*)::int as n,
           (array_agg(split_part(x.full_name, ' ', 1) order by x.score desc))[1:3] as names
    from (
      select r.full_name, r.score
      from public.risk_rows(
        array(select cs.student_id from public.coach_students cs
              where cs.coach_id = c.id),
        -- Pazartesi sabahı: biten hafta (pazartesi-pazar).
        p_now - interval '1 day') r
      where r.score >= 30
      order by r.score desc
      limit 7
    ) x
  ) l
  where c.role = 'coach'
    and (o.license_expires_at is null or o.license_expires_at > p_now)
    and l.n > 0
    and not exists (
      select 1 from public.notifications n
      where n.user_id = c.id and n.kind = 'risk_digest'
        and n.created_at > p_now - interval '5 days');
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.send_risk_digests(timestamptz) from public, anon, authenticated;

-- Pazartesi 05:00 UTC = 08:00 TR.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('risk-digests', '0 5 * * 1',
                          'select public.send_risk_digests()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); zamanlanmadı';
  end if;
end;
$$;
