-- SMS kapandı (NOTLAR §88, §101): artık channel = 'sms' satırı alan gönderici yok.
-- claim_sms ve onu çağıran send-sms Edge Function kaldırılıyor. Kuyruk adı
-- (sms_outbox) ve channel kısıtı ('sms' eski kayıtlar için) kalır.
-- Geri almak için: supabase/rollbacks/20261114110000_drop_claim_sms.down.sql

drop function if exists public.claim_sms(int);
