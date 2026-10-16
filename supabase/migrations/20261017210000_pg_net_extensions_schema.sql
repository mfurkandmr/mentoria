-- =====================================================================
-- pg_net public şemasında kuruluydu (advisor: extension_in_public).
-- Taşınamayan bir eklenti olduğu için extensions şemasında yeniden kurulur.
-- net.http_post her durumda net şemasındadır; push_on_notification etkilenmez.
-- Kuyrukta bekleyen istek varsa kaybolur (canlıya uygulanırken kuyruk boştu).
--
-- Geri almak için: supabase/rollbacks/20261017210000_pg_net_extensions_schema.down.sql
-- =====================================================================
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    drop extension if exists pg_net;
    create schema if not exists extensions;
    create extension pg_net with schema extensions;
  end if;
end;
$$;
