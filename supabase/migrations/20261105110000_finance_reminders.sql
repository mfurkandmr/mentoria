-- =====================================================================
-- Taksit günü bildirimi ve veliye SMS hatırlatması
-- ---------------------------------------------------------------------
--  * finance_fees: due_day (her ayın kaçı, 1-28), payer_name ve payer_phone
--    (ödeyen veli; SMS bu numaraya, +905XXXXXXXXX biçiminde).
--  * finance_installments: due_notified_at (müdüre "günü geldi" bildirimi
--    gitti), reminded_at (son SMS hatırlatması).
--  * notify_due_installments(): her sabah 09.00 (TR) vadesi bugün olan,
--    ödenmemiş taksitler için kurumun müdürlerine tek 'installment_due'
--    bildirimi ("Bugün N taksitin günü geldi, hatırlatma gönderilsin mi?").
--    90 günden eski SMS kayıtlarını da siler (KVKK).
--  * send_payment_reminders(taksitler): yalnızca müdür; ödenmemiş ve veli
--    telefonu olan taksitler için sms_outbox'a mesaj yazar (aynı taksite
--    20 saatte bir). Telefonu olmayan ya da ödenmiş olanlar atlanır.
--  * sms_outbox: gönderilecek SMS'ler. send-sms Edge Function sırayı
--    boşaltır; SMS sağlayıcısı (secrets) tanımlı değilse mesajlar sırada
--    bekler, sağlayıcı bağlanınca gider. Müdür kendi kurumununkileri görür,
--    kimse doğrudan yazamaz.
--
-- Geri almak için: supabase/rollbacks/20261105110000_finance_reminders.down.sql
-- =====================================================================

alter table public.finance_fees
  add column due_day     smallint check (due_day between 1 and 28),
  add column payer_name  text check (length(payer_name) <= 80),
  add column payer_phone text check (payer_phone ~ '^\+905[0-9]{9}$');

alter table public.finance_installments
  add column due_notified_at timestamptz,
  add column reminded_at     timestamptz;
create index on public.finance_installments (due_on) where paid_on is null;

-- Ödeyen bilgisi değişebilir; adı kırp.
create or replace function public.guard_finance_payer()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.payer_name := nullif(trim(new.payer_name), '');
  return new;
end;
$$;
revoke all on function public.guard_finance_payer() from public, anon, authenticated;
create trigger guard_finance_payer before insert or update on public.finance_fees
  for each row execute function public.guard_finance_payer();

create table public.sms_outbox (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references public.tenants (id),
  org_id         uuid not null references public.organizations (id) on delete cascade,
  installment_id uuid references public.finance_installments (id) on delete set null,
  phone          text not null,
  body           text not null,
  status         text not null default 'queued'
                 check (status in ('queued', 'sent', 'failed')),
  error          text,
  created_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now(),
  sent_at        timestamptz
);
create index on public.sms_outbox (status, created_at) where status = 'queued';
create index on public.sms_outbox (org_id, created_at desc);
create index on public.sms_outbox (installment_id);
create index on public.sms_outbox (tenant_id);
create index on public.sms_outbox (created_by);

alter table public.sms_outbox enable row level security;
create policy "finance admin reads sms" on public.sms_outbox
  for select to authenticated
  using ((select public.is_finance_admin(org_id)));
create policy "tenant isolation" on public.sms_outbox as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));
revoke all on public.sms_outbox from anon;
revoke insert, update, delete, truncate, trigger, references
  on public.sms_outbox from authenticated;

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest', 'installment_due'));

-- 12500 → '12.500 TL', 99.5 → '99,50 TL'.
create or replace function public.format_tl(p_amount numeric)
returns text
language sql immutable set search_path = ''
as $$
  select replace(to_char(trunc(p_amount), 'FM999,999,999,990'), ',', '.')
         || case when p_amount <> trunc(p_amount)
                 then ',' || lpad(round((p_amount - trunc(p_amount)) * 100)::int::text, 2, '0')
                 else '' end
         || ' TL'
$$;
revoke all on function public.format_tl(numeric) from public, anon, authenticated;

-- send-sms Edge Function'ı dürt (sırada mesaj varsa). Vault ayarı yoksa
-- (yerel test) sessizce geçer.
create or replace function public.kick_sms()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_url    text;
  v_secret text;
begin
  if not exists (select 1 from public.sms_outbox where status = 'queued') then
    return;
  end if;
  select replace(decrypted_secret, '/send-push', '/send-sms') into v_url
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

-- Her sabah: vadesi bugün olan ödenmemiş taksitler → kurum müdürlerine tek
-- bildirim. Aynı taksit için bir kez.
create or replace function public.notify_due_installments(p_now timestamptz default now())
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_today date := (p_now at time zone 'Europe/Istanbul')::date;
  v_count integer;
begin
  with due as (
    select i.id, i.org_id, i.amount, f.payer_phone
    from public.finance_installments i
    join public.finance_fees f on f.id = i.fee_id
    where i.due_on = v_today and i.paid_on is null and i.due_notified_at is null
  ), per_org as (
    select org_id, count(*)::int n, sum(amount) total,
           count(*) filter (where payer_phone is null)::int no_phone
    from due group by org_id
  ), sent as (
    insert into public.notifications (user_id, kind, data)
    select a.id, 'installment_due',
           jsonb_build_object(
             'count', o.n,
             'total', o.total,
             'no_phone', o.no_phone,
             'due_on', v_today,
             'route', '/admin/finance?remind=' || v_today)
    from per_org o
    join public.profiles a on a.org_id = o.org_id and a.role = 'admin'
    returning 1
  )
  select count(*) into v_count from sent;

  update public.finance_installments
  set due_notified_at = p_now
  where due_on = v_today and paid_on is null and due_notified_at is null;

  delete from public.sms_outbox where created_at < p_now - interval '90 days';
  return v_count;
end;
$$;
revoke all on function public.notify_due_installments(timestamptz) from public, anon, authenticated;

-- Müdür onayıyla veliye SMS hatırlatması (sıraya yazar).
create or replace function public.send_payment_reminders(p_installments uuid[])
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  v_queued int := 0;
  v_no_phone int := 0;
  v_skipped int := 0;
begin
  if coalesce(cardinality(p_installments), 0) > 200 then
    raise exception 'TOO_MANY';
  end if;
  for r in
    select i.id, i.org_id, i.tenant_id, i.amount, i.due_on, i.paid_on,
           i.reminded_at, f.student_name, f.payer_name, f.payer_phone,
           o.name org_name
    from public.finance_installments i
    join public.finance_fees f on f.id = i.fee_id
    join public.organizations o on o.id = i.org_id
    where i.id = any (p_installments)
  loop
    if not public.is_finance_admin(r.org_id) then
      raise exception 'FINANCE_NOT_ADMIN';
    end if;
    if r.paid_on is not null
       or (r.reminded_at is not null and r.reminded_at > now() - interval '20 hours') then
      v_skipped := v_skipped + 1;
    elsif r.payer_phone is null then
      v_no_phone := v_no_phone + 1;
    else
      insert into public.sms_outbox
        (tenant_id, org_id, installment_id, phone, body, created_by)
      values (
        r.tenant_id, r.org_id, r.id, r.payer_phone,
        format('Sayın %s, %s: %s için %s vadeli %s taksit ödemesini hatırlatırız.',
               coalesce(r.payer_name, 'Veli'), r.org_name, r.student_name,
               to_char(r.due_on, 'DD.MM.YYYY'), public.format_tl(r.amount)),
        auth.uid());
      update public.finance_installments set reminded_at = now() where id = r.id;
      v_queued := v_queued + 1;
    end if;
  end loop;
  if v_queued > 0 then
    perform public.kick_sms();
  end if;
  return jsonb_build_object('queued', v_queued, 'no_phone', v_no_phone,
                            'skipped', v_skipped);
end;
$$;
revoke all on function public.send_payment_reminders(uuid[]) from public, anon;
grant execute on function public.send_payment_reminders(uuid[]) to authenticated;

-- 06:00 UTC = 09:00 TR; SMS sırası 5 dakikada bir (sağlayıcı sonradan
-- bağlanırsa bekleyenler de gider).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('due-installments', '0 6 * * *',
                          'select public.notify_due_installments()');
    perform cron.schedule('sms-outbox', '*/5 * * * *',
                          'select public.kick_sms()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); zamanlanmadı';
  end if;
end;
$$;
