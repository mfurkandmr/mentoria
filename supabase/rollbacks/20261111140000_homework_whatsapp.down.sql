-- 20261111140000_homework_whatsapp geri alma. Kovadaki PDF'ler silinmez
-- (Storage API ile elle silinebilir); kuyruktaki ödev / koç mesajları kalır.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron')
     and exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule('homework-pdf-retention')
    where exists (select 1 from cron.job where jobname = 'homework-pdf-retention');
  end if;
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    execute 'drop policy if exists "manager uploads homework pdf" on storage.objects';
    execute 'drop policy if exists "manager reads homework pdf" on storage.objects';
  end if;
end $$;
drop function if exists public.purge_homework_pdfs(timestamptz);
drop function if exists public.guardian_messages(uuid);
drop function if exists public.send_guardian_message(uuid, text);
drop function if exists public.queue_homework_whatsapp(uuid);
drop function if exists public._homework_pdf_exists(text);
drop function if exists public.can_manage_assignment(uuid);
drop index if exists public.sms_outbox_assignment_once;
drop index if exists public.sms_outbox_student_id;
alter table public.sms_outbox
  drop column if exists assignment_id,
  drop column if exists student_id;
