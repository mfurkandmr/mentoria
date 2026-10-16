-- Geri alma: 20261017160000_push_webhook
-- (pg_net eklentisi başka işler kullanıyor olabilir; kaldırılmaz.)
drop trigger if exists push_on_notification on public.notifications;
drop function if exists public.push_on_notification();
-- Vault ayarlarını da kaldırmak isterseniz:
--   delete from vault.secrets where name in ('push_function_url', 'push_webhook_secret');
