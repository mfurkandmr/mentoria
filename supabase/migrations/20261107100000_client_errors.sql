-- =====================================================================
-- Web hata kaydı (NOTLAR §66)
-- ---------------------------------------------------------------------
-- Crashlytics web'de çalışmadığı için web panelinde yakalanmayan hatalar
-- buraya yazılır. KVKK: kimliksiz. Kullanıcı kimliği, e-posta, IP adresi
-- tutulmaz; adres yalnızca yol olarak gelir (sorgu ve # kısmı istemcide
-- atılır, burada da kesilir). Tarayıcı bilgisi kısaltılır.
--
-- - Aynı hata (aynı sürüm + aynı parmak izi) ayrı satır açmaz, sayacı
--   artar (`count`, `last_seen`).
-- - Yalnızca report_client_error() yazar (giriş yapmamış ziyaretçi de:
--   giriş ekranındaki hatalar). Tabloyu yalnızca süper admin okur/siler.
-- - Taşma koruması: son bir saatte 500'den fazla yeni satır açıldıysa yeni
--   hata yazılmaz (var olanların sayacı yine artar). 90 günden eski kayıtlar
--   yazarken ara ara silinir.
--
-- Geri almak için: supabase/rollbacks/20261107100000_client_errors.down.sql
-- =====================================================================

create table public.client_errors (
  id          bigint generated always as identity primary key,
  fingerprint text        not null,
  app_version text        not null,
  platform    text        not null check (platform in ('web', 'android', 'ios')),
  message     text        not null,
  stack       text,
  url_path    text,
  user_agent  text,
  count       int         not null default 1,
  first_seen  timestamptz not null default now(),
  last_seen   timestamptz not null default now(),
  unique (fingerprint, app_version)
);

create index client_errors_last_seen_idx on public.client_errors (last_seen desc);

alter table public.client_errors enable row level security;
revoke all on public.client_errors from public, anon, authenticated;
grant select, delete on public.client_errors to authenticated;

create policy "super admin reads client errors" on public.client_errors
  for select to authenticated using (public.is_super_admin());
create policy "super admin deletes client errors" on public.client_errors
  for delete to authenticated using (public.is_super_admin());

create or replace function public.report_client_error(
  p_message text,
  p_stack text default null,
  p_url_path text default null,
  p_platform text default 'web',
  p_app_version text default '',
  p_user_agent text default null
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_message text := left(coalesce(nullif(trim(p_message), ''), '?'), 1000);
  v_stack   text := left(p_stack, 8000);
  v_version text := left(coalesce(p_app_version, ''), 40);
  v_path    text := left(split_part(split_part(coalesce(p_url_path, ''), '?', 1), '#', 1), 300);
  v_fp      text;
begin
  if p_platform not in ('web', 'android', 'ios') then
    return;
  end if;
  -- Parmak izi: mesaj (sayılar atılır: aynı hata farklı kimliklerle) +
  -- yığının ilk satırı.
  v_fp := md5(
    regexp_replace(v_message, '[0-9]+', '#', 'g') || '|' ||
    coalesce(split_part(v_stack, E'\n', 1), '')
  );

  update public.client_errors
     set count = count + 1, last_seen = now()
   where fingerprint = v_fp and app_version = v_version;
  if found then
    return;
  end if;

  if (select count(*) from public.client_errors
       where first_seen > now() - interval '1 hour') >= 500 then
    return;
  end if;

  insert into public.client_errors
    (fingerprint, app_version, platform, message, stack, url_path, user_agent)
  values
    (v_fp, v_version, p_platform, v_message, v_stack, nullif(v_path, ''),
     left(p_user_agent, 300))
  on conflict (fingerprint, app_version)
    do update set count = public.client_errors.count + 1, last_seen = now();

  -- Ara ara (yaklaşık her 50 yeni hatada bir) eski kayıtları temizle.
  if random() < 0.02 then
    delete from public.client_errors where last_seen < now() - interval '90 days';
  end if;
end;
$$;

revoke execute on function public.report_client_error(text, text, text, text, text, text) from public;
grant  execute on function public.report_client_error(text, text, text, text, text, text) to anon, authenticated;
