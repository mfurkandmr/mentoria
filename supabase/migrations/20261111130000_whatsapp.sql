-- =====================================================================
-- Veli mesajları SMS yerine WhatsApp'tan (OGRETMEN_WHATSAPP_PLANI.md §C)
-- ---------------------------------------------------------------------
-- Kurum SMS'i tamamen bırakıyor; velilere giden her şey kurumun WhatsApp
-- Business numarasından (Cloud API) gider.
--
--  * Kuyruk aynı kalır: public.sms_outbox. Yoklama, taksit hatırlatma, toplu
--    mesaj ve deneme sonucu bugünkü gibi buraya yazar; adı değiştirilmedi
--    çünkü bu fonksiyonların hepsi adı metin olarak kullanıyor. Yeni sütunlar:
--      channel     'whatsapp' (varsayılan) | 'sms' (yalnızca eski kayıtlar)
--      template    Meta onaylı şablon adı; boşsa kurumun genel
--                  bilgilendirme şablonu kullanılır (metin değişken olarak)
--      params      şablon değişkenleri (jsonb dizi, sırayla {{1}}, {{2}}…)
--      media_path  ek dosya (ödev PDF'i; Storage yolu)
--      wa_message_id, delivered_at, read_at  webhook'tan gelen durum
--  * org_whatsapp: kurumun bağlantısı (phone_number_id, waba_id, erişim
--    anahtarı). İstemci tabloyu hiç okuyamaz; müdür yalnızca durumunu ve
--    numarayı görür, anahtar geri dönmez.
--  * claim_messages(): send-whatsapp Edge Function'ı için kilitli alma
--    (claim_sms ile aynı kural: çift gönderim yok, yarıda kalan 'failed').
--    Yalnızca WhatsApp'ı bağlı kurumların mesajlarını alır; bağlı olmayan
--    kurumun mesajları kuyrukta bekler.
--  * claim_sms artık yalnızca channel = 'sms' satırları alır (send-sms
--    çalışırsa bile WhatsApp mesajlarına dokunmaz).
--  * kick_sms() artık send-whatsapp'ı dürter (adı korunuyor: yoklama, taksit,
--    toplu mesaj fonksiyonları bu adla çağırıyor).
--  * whatsapp_mark(): whatsapp-webhook teslim / okundu / hata yazar.
--
-- Geri almak için: supabase/rollbacks/20261111130000_whatsapp.down.sql
-- =====================================================================

alter table public.sms_outbox
  add column if not exists channel text not null default 'whatsapp'
    check (channel in ('whatsapp', 'sms')),
  add column if not exists template text,
  add column if not exists params jsonb,
  add column if not exists media_path text,
  add column if not exists wa_message_id text,
  add column if not exists delivered_at timestamptz,
  add column if not exists read_at timestamptz;
create index if not exists sms_outbox_wa_message_id
  on public.sms_outbox (wa_message_id) where wa_message_id is not null;

-- Sırada bekleyen eski SMS'ler de WhatsApp'tan gitsin (SMS kapandı).
update public.sms_outbox set channel = 'whatsapp' where status = 'queued';

create table public.org_whatsapp (
  org_id          uuid primary key references public.organizations (id) on delete cascade,
  phone_number_id text not null check (phone_number_id ~ '^[0-9]{5,30}$'),
  waba_id         text not null check (waba_id ~ '^[0-9]{5,30}$'),
  display_phone   text check (length(display_phone) <= 30),
  access_token    text not null check (length(access_token) between 20 and 1000),
  template_name   text not null default 'kurum_bilgilendirme'
                  check (template_name ~ '^[a-z0-9_]{1,100}$'),
  template_lang   text not null default 'tr' check (template_lang ~ '^[a-z]{2}(_[A-Z]{2})?$'),
  connected_at    timestamptz not null default now(),
  updated_by      uuid references public.profiles (id) on delete set null
);
create index on public.org_whatsapp (updated_by);
alter table public.org_whatsapp enable row level security;
-- Politika yok: istemci (anon / authenticated) hiçbir satırı göremez.
revoke all on public.org_whatsapp from public, anon, authenticated;

-- Müdür: bağlantı durumu ve son 30 günün mesaj sayıları. Anahtar dönmez.
create or replace function public.org_whatsapp_status()
returns table (
  connected boolean, display_phone text, phone_number_id text, waba_id text,
  template_name text, connected_at timestamptz,
  queued int, sent int, delivered int, read int, failed int)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_org uuid := public.my_org();
begin
  if v_org is null or not public.is_org_admin(v_org) then
    raise exception 'NOT_ALLOWED';
  end if;
  return query
  select w.org_id is not null, w.display_phone, w.phone_number_id, w.waba_id,
         coalesce(w.template_name, 'kurum_bilgilendirme'), w.connected_at,
         s.queued, s.sent, s.delivered, s.read, s.failed
  from (select 1) one
  left join public.org_whatsapp w on w.org_id = v_org
  cross join lateral (
    select count(*) filter (where o.status in ('queued', 'sending'))::int queued,
           count(*) filter (where o.status = 'sent')::int sent,
           count(*) filter (where o.delivered_at is not null)::int delivered,
           count(*) filter (where o.read_at is not null)::int read,
           count(*) filter (where o.status = 'failed')::int failed
    from public.sms_outbox o
    where o.org_id = v_org and o.created_at > now() - interval '30 days') s;
end;
$$;
revoke all on function public.org_whatsapp_status() from public, anon;
grant execute on function public.org_whatsapp_status() to authenticated;

-- Müdür: bağla / güncelle. p_token boşsa kayıtlı anahtar korunur (yalnızca
-- numara bilgisi değişir); ilk bağlantıda zorunlu.
create or replace function public.set_org_whatsapp(
  p_phone_number_id text, p_waba_id text, p_display_phone text,
  p_token text default null, p_template text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_org   uuid := public.my_org();
  v_token text := nullif(trim(coalesce(p_token, '')), '');
  v_tpl   text := coalesce(nullif(trim(coalesce(p_template, '')), ''), 'kurum_bilgilendirme');
begin
  if v_org is null or not public.is_org_admin(v_org) then
    raise exception 'NOT_ALLOWED';
  end if;
  if trim(coalesce(p_phone_number_id, '')) !~ '^[0-9]{5,30}$'
     or trim(coalesce(p_waba_id, '')) !~ '^[0-9]{5,30}$' then
    raise exception 'WA_BAD_ID';
  end if;
  if v_tpl !~ '^[a-z0-9_]{1,100}$' then
    raise exception 'WA_BAD_TEMPLATE';
  end if;
  if v_token is not null and length(v_token) not between 20 and 1000 then
    raise exception 'WA_BAD_TOKEN';
  end if;
  if v_token is null and not exists (select 1 from public.org_whatsapp where org_id = v_org) then
    raise exception 'WA_TOKEN_REQUIRED';
  end if;

  update public.org_whatsapp w set
    phone_number_id = trim(p_phone_number_id),
    waba_id         = trim(p_waba_id),
    display_phone   = nullif(left(trim(coalesce(p_display_phone, '')), 30), ''),
    access_token    = coalesce(v_token, w.access_token),
    template_name   = v_tpl,
    updated_by      = auth.uid(),
    connected_at    = case when v_token is null then w.connected_at else now() end
  where w.org_id = v_org;
  if not found then
    insert into public.org_whatsapp
      (org_id, phone_number_id, waba_id, display_phone, access_token, template_name, updated_by)
    values (v_org, trim(p_phone_number_id), trim(p_waba_id),
            nullif(left(trim(coalesce(p_display_phone, '')), 30), ''),
            v_token, v_tpl, auth.uid());
  end if;

  perform public.kick_sms();
end;
$$;
revoke all on function public.set_org_whatsapp(text, text, text, text, text) from public, anon;
grant execute on function public.set_org_whatsapp(text, text, text, text, text) to authenticated;

-- Müdür: bağlantıyı kaldır (anahtar silinir). Mesajlar kuyrukta bekler.
create or replace function public.disconnect_org_whatsapp()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.my_org();
begin
  if v_org is null or not public.is_org_admin(v_org) then
    raise exception 'NOT_ALLOWED';
  end if;
  delete from public.org_whatsapp where org_id = v_org;
end;
$$;
revoke all on function public.disconnect_org_whatsapp() from public, anon;
grant execute on function public.disconnect_org_whatsapp() to authenticated;

-- send-whatsapp: kilitli alma. Bağlantı bilgileri satırla birlikte döner
-- (yalnızca service role çağırır).
create or replace function public.claim_messages(p_limit int default 50)
returns table (
  id uuid, phone text, body text, template text, params jsonb, media_path text,
  org_name text, phone_number_id text, access_token text,
  default_template text, template_lang text)
language plpgsql security definer set search_path = ''
as $$
begin
  update public.sms_outbox o
  set status = 'failed', error = 'zaman aşımı (gönderilmiş olabilir)'
  where o.status = 'sending' and o.channel = 'whatsapp'
    and o.claimed_at < now() - interval '15 minutes';

  return query
  with due as (
    select o.id from public.sms_outbox o
    where o.status = 'queued' and o.channel = 'whatsapp'
      and exists (select 1 from public.org_whatsapp w where w.org_id = o.org_id)
    order by o.created_at
    limit greatest(1, least(coalesce(p_limit, 50), 200))
    for update of o skip locked
  ), claimed as (
    update public.sms_outbox o
    set status = 'sending', claimed_at = now()
    from due
    where o.id = due.id
    returning o.id, o.org_id, o.phone, o.body, o.template, o.params, o.media_path, o.created_at
  )
  select c.id, c.phone, c.body, c.template, c.params, c.media_path,
         g.name, w.phone_number_id, w.access_token, w.template_name, w.template_lang
  from claimed c
  join public.org_whatsapp w on w.org_id = c.org_id
  join public.organizations g on g.id = c.org_id
  order by c.created_at;
end;
$$;
revoke all on function public.claim_messages(int) from public, anon, authenticated;

-- Eski SMS gönderici yalnızca SMS kanalındaki satırlara dokunur.
create or replace function public.claim_sms(p_limit int default 50)
returns table (id uuid, phone text, body text)
language plpgsql security definer set search_path = ''
as $$
begin
  update public.sms_outbox o
  set status = 'failed', error = 'zaman aşımı (gönderilmiş olabilir)'
  where o.status = 'sending' and o.channel = 'sms'
    and o.claimed_at < now() - interval '15 minutes';

  return query
  with due as (
    select o.id from public.sms_outbox o
    where o.status = 'queued' and o.channel = 'sms'
    order by o.created_at
    limit greatest(1, least(coalesce(p_limit, 50), 200))
    for update skip locked
  )
  update public.sms_outbox o
  set status = 'sending', claimed_at = now()
  from due
  where o.id = due.id
  returning o.id, o.phone, o.body;
end;
$$;
revoke all on function public.claim_sms(int) from public, anon, authenticated;

-- Webhook: Meta'nın durum bildirimi. Durum yalnızca ileri gider
-- (okundu bilgisi teslimden önce gelirse teslim de yazılır).
create or replace function public.whatsapp_mark(
  p_wa_id text, p_status text, p_error text default null, p_at timestamptz default now())
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_n int;
begin
  update public.sms_outbox o set
    delivered_at = case when p_status in ('delivered', 'read')
                        then coalesce(o.delivered_at, p_at) else o.delivered_at end,
    read_at      = case when p_status = 'read' then coalesce(o.read_at, p_at) else o.read_at end,
    status       = case when p_status = 'failed' then 'failed' else o.status end,
    error        = case when p_status = 'failed'
                        then left(coalesce(p_error, 'WhatsApp teslim edemedi'), 200)
                        else o.error end
  where o.wa_message_id = p_wa_id;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke all on function public.whatsapp_mark(text, text, text, timestamptz) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.claim_messages(int) to service_role;
    grant execute on function public.claim_sms(int) to service_role;
    grant execute on function public.whatsapp_mark(text, text, text, timestamptz) to service_role;
  end if;
end $$;

-- Kuyruğu dürt: artık send-whatsapp. Vault ayarı yoksa (yerel test) geçer.
create or replace function public.kick_sms()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_url    text;
  v_secret text;
begin
  if not exists (
    select 1 from public.sms_outbox o
    where o.status = 'queued' and o.channel = 'whatsapp'
      and exists (select 1 from public.org_whatsapp w where w.org_id = o.org_id)) then
    return;
  end if;
  select replace(decrypted_secret, '/send-push', '/send-whatsapp') into v_url
  from vault.decrypted_secrets where name = 'push_function_url';
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_url is null or v_secret is null then
    return;
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000);
exception when others then
  raise warning 'kick_sms: %', sqlerrm;
end;
$$;
revoke all on function public.kick_sms() from public, anon, authenticated;
