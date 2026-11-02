-- =====================================================================
-- KVKK saklama süreleri (docs/kvkk/06_saklama_imha_politikasi.md)
-- ---------------------------------------------------------------------
-- Her gece çalışan üç imha görevi:
--  * Eski duyurular: announcements_keep (1 yıl) geçen duyurular ve onların
--    'announcement' bildirimleri silinir.
--  * Lisansı biten kurum: license_expires_at üzerinden expired_org_keep
--    (1 yıl) geçmişse kurumdaki tüm hesaplar (veriler cascade ile) silinir.
--    Lisans yenilenirse tarih ileri alındığı için hiçbir şey silinmez.
--  * Uzun süre kullanılmayan hesap: son etkinlikten inactive_after (2 yıl)
--    eksi inactive_warning (30 gün) geçince 'inactivity_warning' bildirimi
--    (telefon bildirimi de gider), uyarıdan en az inactive_warning sonra hâlâ
--    etkinlik yoksa hesap silinir. Kullanıcı arada açarsa uyarı kaydı düşer.
--    Son etkinlik: kayıt, son giriş ve oturum yenileme (refresh token)
--    zamanlarının en yenisi; uygulama açık kaldıkça oturum yenilendiği için
--    "hiç çıkış yapmayan" kullanıcı yanlışlıkla silinmez.
--    Silinmeyenler: platform yöneticileri, öğrencisi olan koç (öğrenciler
--    koçsuz kalmasın) ve öğrencisi olan kurumun tek müdürü.
--
-- Süreler retention_settings'te; değiştirmek için (SQL Editor):
--   update public.retention_settings set inactive_after = '3 years';
-- Elle çalıştırmak için: select public.run_retention_jobs();
--
-- Geri almak için: supabase/rollbacks/20261029100000_retention_jobs.down.sql
-- =====================================================================

create table public.retention_settings (
  id                 boolean primary key default true check (id),
  announcements_keep interval not null default '1 year'
                     check (announcements_keep >= interval '30 days'),
  expired_org_keep   interval not null default '1 year'
                     check (expired_org_keep >= interval '30 days'),
  inactive_after     interval not null default '2 years'
                     check (inactive_after >= interval '180 days'),
  inactive_warning   interval not null default '30 days'
                     check (inactive_warning between interval '7 days' and interval '90 days'),
  updated_at         timestamptz not null default now()
);
insert into public.retention_settings default values;
alter table public.retention_settings enable row level security;
-- Politika yok: yalnızca görevler ve platform yöneticisi (SQL) okur/yazar.
revoke all on public.retention_settings from anon, authenticated;

-- Uyarı gönderilen hareketsiz hesaplar.
create table public.inactivity_warnings (
  user_id   uuid primary key references public.profiles (id) on delete cascade,
  warned_at timestamptz not null default now()
);
alter table public.inactivity_warnings enable row level security;
revoke all on public.inactivity_warnings from anon, authenticated;

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning'));

-- 1. Eski duyurular -------------------------------------------------------------
create or replace function public.purge_old_announcements()
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_keep interval;
  v_n    int;
begin
  select announcements_keep into v_keep from public.retention_settings;
  with gone as (
    delete from public.announcements
    where created_at < now() - v_keep
    returning id
  ), notes as (
    delete from public.notifications n
    using gone
    where n.kind = 'announcement' and n.ref_id = gone.id
  )
  select count(*) into v_n from gone;
  return v_n;
end;
$$;
revoke execute on function public.purge_old_announcements() from public, anon, authenticated;

-- 2. Lisansı biten kurumlar -----------------------------------------------------
create or replace function public.purge_expired_organizations()
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_keep interval;
  v_n    int;
begin
  select expired_org_keep into v_keep from public.retention_settings;
  delete from auth.users
  where id in (
    select p.id
    from public.profiles p
    join public.organizations o on o.id = p.org_id
    where o.license_expires_at < now() - v_keep
      and not exists (select 1 from public.platform_admins pa where pa.user_id = p.id)
  );
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.purge_expired_organizations() from public, anon, authenticated;

-- 3. Uzun süre kullanılmayan hesaplar -------------------------------------------
-- Son etkinlik: kayıt, son giriş, en son oturum yenileme.
-- (auth.refresh_tokens.user_id metin, updated_at saat dilimsiz UTC.)
create or replace function public.user_last_activity()
returns table (user_id uuid, last_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
  return query
  select u.id,
         greatest(u.created_at, u.last_sign_in_at,
                  (select max(rt.updated_at) at time zone 'UTC'
                   from auth.refresh_tokens rt
                   where rt.user_id = u.id::text))
  from auth.users u
  join public.profiles p on p.id = u.id
  where not exists (select 1 from public.platform_admins pa where pa.user_id = u.id);
end;
$$;
revoke execute on function public.user_last_activity() from public, anon, authenticated;

create or replace function public.process_inactive_accounts()
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_s       public.retention_settings%rowtype;
  v_warned  int;
  v_deleted int;
begin
  select * into v_s from public.retention_settings;

  drop table if exists _activity;
  create temp table _activity on commit drop as
    select * from public.user_last_activity();

  -- Uyarıdan sonra uygulamayı açanlar baştan başlar.
  delete from public.inactivity_warnings w
  using _activity a
  where a.user_id = w.user_id and a.last_at > w.warned_at;

  -- Süresi dolan ve en az inactive_warning önce uyarılanlar silinir.
  delete from auth.users
  where id in (
    select a.user_id
    from _activity a
    join public.inactivity_warnings w on w.user_id = a.user_id
    join public.profiles p on p.id = a.user_id
    where a.last_at < now() - v_s.inactive_after
      and w.warned_at <= now() - v_s.inactive_warning
      -- Öğrencileri koçsuz bırakma.
      and not (p.role = 'coach'
               and exists (select 1 from public.coach_students cs where cs.coach_id = p.id))
      -- Öğrencisi olan kurumu müdürsüz bırakma.
      and not (p.role = 'admin'
               and exists (select 1 from public.profiles s
                           where s.org_id = p.org_id and s.role = 'student')
               and not exists (select 1 from public.profiles o
                               where o.org_id = p.org_id and o.role = 'admin'
                                 and o.id <> p.id))
  );
  get diagnostics v_deleted = row_count;

  -- Silinmeye inactive_warning kalanlara bir kez uyarı.
  with fresh as (
    insert into public.inactivity_warnings (user_id)
    select a.user_id from _activity a
    -- Az önce silinenler hariç.
    join public.profiles p on p.id = a.user_id
    where a.last_at < now() - (v_s.inactive_after - v_s.inactive_warning)
    on conflict (user_id) do nothing
    returning user_id
  )
  insert into public.notifications (user_id, kind, data)
  select f.user_id, 'inactivity_warning',
         jsonb_build_object('days', extract(day from v_s.inactive_warning)::int)
  from fresh f;
  get diagnostics v_warned = row_count;

  return jsonb_build_object('warned', v_warned, 'deleted', v_deleted);
end;
$$;
revoke execute on function public.process_inactive_accounts() from public, anon, authenticated;

-- Hepsi bir arada (gece görevi ve elle çalıştırma için).
create or replace function public.run_retention_jobs()
returns jsonb
language plpgsql security definer set search_path = ''
as $$
begin
  return jsonb_build_object(
    'announcements', public.purge_old_announcements(),
    'expired_org_accounts', public.purge_expired_organizations(),
    'inactive', public.process_inactive_accounts());
end;
$$;
revoke execute on function public.run_retention_jobs() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    -- 03.30 Türkiye saati.
    perform cron.schedule('retention-jobs', '30 0 * * *',
      'select public.run_retention_jobs()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); zamanlanmadı';
  end if;
end;
$$;
