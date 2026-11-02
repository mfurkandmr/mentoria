-- Geri alma: 20261029100000_retention_jobs
-- Gece görevi, saklama fonksiyonları ve tabloları kalkar; bildirim türleri
-- eski haline döner (bu türdeki bildirimler önce silinir).
-- pg_cron uzantısı yerinde bırakılır (başka işler kullanıyor).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('retention-jobs');
  end if;
exception
  when others then
    raise notice 'retention-jobs işi bulunamadı: %', sqlerrm;
end;
$$;

drop function if exists public.run_retention_jobs();
drop function if exists public.process_inactive_accounts();
drop function if exists public.user_last_activity();
drop function if exists public.purge_expired_organizations();
drop function if exists public.purge_old_announcements();
drop table if exists public.inactivity_warnings;
drop table if exists public.retention_settings;

delete from public.notifications where kind = 'inactivity_warning';
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement'));
