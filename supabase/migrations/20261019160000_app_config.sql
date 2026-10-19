-- Zorunlu güncelleme: sunucu tarafı değişince eski uygulama sürümleri
-- bozulabiliyor (ör. bildirimlerin Realtime'dan çıkması). Uygulama açılışta
-- buradaki min_build'i kendi derleme numarasıyla (pubspec version'daki +N)
-- karşılaştırır; eskiyse "Güncelleme gerekli" ekranını gösterir.
--
-- Değiştirmek için (platform yöneticisi, SQL Editor):
--   update public.app_config set min_build = 3,
--     update_url = 'https://play.google.com/store/apps/details?id=com.mentoria.mentoria';
-- Geri almak için: supabase/rollbacks/20261019160000_app_config.down.sql

create table public.app_config (
  id         boolean primary key default true check (id),
  -- Bu derleme numarasından eski uygulamalar açılmaz.
  min_build  int not null default 1 check (min_build >= 1),
  -- "Güncelle" düğmesinin açacağı adres (mağaza ya da APK indirme sayfası).
  update_url text check (update_url is null or update_url ~ '^https://'),
  -- İsteğe bağlı açıklama (boşsa uygulamadaki varsayılan metin).
  message    text check (message is null or length(message) <= 300),
  updated_at timestamptz not null default now()
);
insert into public.app_config default values;

alter table public.app_config enable row level security;
-- Girişten önce de okunur (eski sürüm giriş ekranında da durmalı).
create policy "read app config" on public.app_config
  for select to anon, authenticated using (true);
-- Güvenlik sıkılaştırması yeni tablolarda varsayılan yetkiyi kapattığı için açıkça.
grant select on public.app_config to anon, authenticated;
revoke insert, update, delete on public.app_config from anon, authenticated;
