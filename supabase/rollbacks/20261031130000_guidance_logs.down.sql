-- Geri alma: 20261031130000_guidance_logs
-- Rehberlik kayıtları silinir.
drop table if exists public.guidance_logs;
drop function if exists public.guard_guidance_log();
