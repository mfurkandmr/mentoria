-- Geri alma: 20261017180000_account_deletion_requests
-- Talep fonksiyonu ve tablosu kalkar; bildirim türleri eski haline döner
-- (bu türdeki bildirimler önce silinir, yoksa kısıt eklenemez).
drop function if exists public.request_account_deletion();
drop table if exists public.account_deletion_requests;

delete from public.notifications where kind = 'deletion_request';
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note'));
