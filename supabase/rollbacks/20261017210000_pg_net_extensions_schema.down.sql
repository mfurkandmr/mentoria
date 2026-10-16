-- Geri alma: 20261017210000_pg_net_extensions_schema (pg_net public'e döner)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_net') then
    drop extension pg_net;
    create extension pg_net;
  end if;
end;
$$;
