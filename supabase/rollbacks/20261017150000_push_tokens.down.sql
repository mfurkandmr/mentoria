-- Geri alma: 20261017150000_push_tokens
-- (Önce 20261017160000_push_webhook.down.sql çalıştırılmalı.)
drop function if exists public.unregister_device_token(text);
drop function if exists public.register_device_token(text, text);
drop table if exists public.device_tokens;
