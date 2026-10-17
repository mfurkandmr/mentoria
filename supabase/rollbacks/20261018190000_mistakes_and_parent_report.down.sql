-- Geri alma: 20261018190000_mistakes_and_parent_report
-- Zamanlanmış işler, hata defteri ve bildirim türleri kalkar (bu türdeki
-- bildirimler önce silinir). Kovadaki fotoğraflar Storage'da kalır; gerekirse
-- panelden "mistake-photos" kovası silinir.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('review-reminders');
    exception when others then
      raise notice 'review-reminders yok: %', sqlerrm;
    end;
    begin
      perform cron.unschedule('parent-weekly-reports');
    exception when others then
      raise notice 'parent-weekly-reports yok: %', sqlerrm;
    end;
  end if;
end;
$$;

drop function if exists public.send_parent_weekly_reports(timestamptz);
drop function if exists public.send_review_reminders(timestamptz);
drop function if exists public.review_mistake(uuid, boolean);
drop table if exists public.mistake_cards;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    drop policy if exists "student uploads mistake photos" on storage.objects;
    drop policy if exists "student deletes mistake photos" on storage.objects;
    drop policy if exists "viewers read mistake photos" on storage.objects;
  end if;
end;
$$;

delete from public.notifications where kind in ('review', 'weekly_report');
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request', 'meeting'));
