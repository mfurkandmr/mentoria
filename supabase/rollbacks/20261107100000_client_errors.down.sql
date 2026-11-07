-- Geri alma: 20261107100000_client_errors (web hata kaydı).
drop function if exists public.report_client_error(text, text, text, text, text, text);
drop table if exists public.client_errors;
