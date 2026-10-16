-- =====================================================================
-- Telefon bildirimleri (Firebase Cloud Messaging) 1/2: cihaz adresleri
--
--  * device_tokens: kullanıcının cihazlarının FCM adresleri. Aynı cihazda
--    başka hesapla giriş yapılırsa adres yeni kullanıcıya geçer.
--  * Yazma yalnızca register/unregister fonksiyonlarıyla; kullanıcı yalnızca
--    kendi adreslerini görür. Hesap silinince adresler de silinir.
--  * Gönderimi Edge Function yapar (service role), bkz. 2/2.
--
-- Geri almak için: supabase/rollbacks/20261017150000_push_tokens.down.sql
-- =====================================================================

create table public.device_tokens (
  token        text primary key check (length(token) between 20 and 4096),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  tenant_id    uuid references public.tenants (id) on delete cascade,
  platform     text not null check (platform in ('android', 'ios', 'web')),
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index on public.device_tokens (user_id);
create index on public.device_tokens (tenant_id);

alter table public.device_tokens enable row level security;

create policy "read own device tokens" on public.device_tokens
  for select to authenticated using (user_id = (select auth.uid()));
create policy "delete own device tokens" on public.device_tokens
  for delete to authenticated using (user_id = (select auth.uid()));
create policy "tenant isolation" on public.device_tokens as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant()))
  with check (tenant_id = (select public.my_tenant()));
revoke insert, update on public.device_tokens from anon, authenticated;

-- Uygulama açılışta ve adres yenilenince çağırır.
create or replace function public.register_device_token(p_token text, p_platform text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_platform not in ('android', 'ios', 'web') then
    raise exception 'INVALID_PLATFORM';
  end if;

  insert into public.device_tokens (token, user_id, tenant_id, platform)
  values (trim(p_token), v_me.id, v_me.tenant_id, p_platform)
  on conflict (token) do update
    set user_id = excluded.user_id,
        tenant_id = excluded.tenant_id,
        platform = excluded.platform,
        last_seen_at = now();

  -- Bir kullanıcının en fazla 10 cihazı: en eskiler bırakılır.
  delete from public.device_tokens
  where user_id = v_me.id
    and token not in (select token from public.device_tokens
                      where user_id = v_me.id
                      order by last_seen_at desc limit 10);
end;
$$;

-- Çıkış yaparken çağrılır (yalnızca kendi adresini siler).
create or replace function public.unregister_device_token(p_token text)
returns void
language sql security definer set search_path = ''
as $$
  delete from public.device_tokens
  where token = trim(p_token) and user_id = auth.uid()
$$;

revoke execute on function public.register_device_token(text, text) from public, anon;
grant  execute on function public.register_device_token(text, text) to authenticated;
revoke execute on function public.unregister_device_token(text)     from public, anon;
grant  execute on function public.unregister_device_token(text)     to authenticated;
