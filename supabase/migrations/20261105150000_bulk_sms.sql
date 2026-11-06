-- =====================================================================
-- Kurum müdürünün velilere serbest metinli SMS'i (resmi tatil, duyuru…)
-- ---------------------------------------------------------------------
--  * sms_broadcasts: gönderim kaydı (metin, kime, kaç numara, kim).
--  * send_bulk_sms(metin, kime, sınıflar, öğrenciler, deneme):
--    kime = 'all' | 'classes' | 'students'. Velinin numarası
--    guardian_phone_of (yoklama için girilen, yoksa finanstaki ödeyen veli).
--    Aynı numara bir kez (kardeşler). Metnin başına kurum adı eklenir.
--    p_dry_run: yalnızca sayar (kaç numara, kaç öğrencinin telefonu yok).
--    En çok 2000 numara; kurum başına 10 dakikada bir gönderim.
--  * sms_outbox.broadcast_id; müdür kendi kurumunun kayıtlarını görür.
--  SMS sağlayıcısı bağlanana kadar mesajlar sırada bekler (send-sms).
--
-- Geri almak için: supabase/rollbacks/20261105150000_bulk_sms.down.sql
-- =====================================================================

create table public.sms_broadcasts (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations (id) on delete cascade,
  tenant_id   uuid not null references public.tenants (id),
  body        text not null check (length(body) between 1 and 600),
  audience    text not null check (audience in ('all', 'classes', 'students')),
  recipients  integer not null default 0,
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index on public.sms_broadcasts (org_id, created_at desc);
create index on public.sms_broadcasts (tenant_id);
create index on public.sms_broadcasts (created_by);

alter table public.sms_broadcasts enable row level security;
create policy "org admin reads broadcasts" on public.sms_broadcasts
  for select to authenticated
  using ((select public.is_org_admin(org_id)));
create policy "tenant isolation" on public.sms_broadcasts as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()));
revoke all on public.sms_broadcasts from anon;
revoke insert, update, delete, truncate, trigger, references
  on public.sms_broadcasts from authenticated;

alter table public.sms_outbox
  add column broadcast_id uuid references public.sms_broadcasts (id) on delete cascade;
create index on public.sms_outbox (broadcast_id);

create or replace function public.send_bulk_sms(
  p_body text,
  p_audience text,
  p_classrooms uuid[] default null,
  p_students uuid[] default null,
  p_dry_run boolean default false)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_me       public.profiles%rowtype;
  v_org      public.organizations%rowtype;
  v_body     text := trim(coalesce(p_body, ''));
  v_full     text;
  v_students uuid[];
  v_phones   text[];
  v_no_phone int;
  v_id       uuid;
begin
  select * into v_me from public.profiles where id = auth.uid() and role = 'admin';
  if not found then
    raise exception 'NOT_ALLOWED';
  end if;
  select * into v_org from public.organizations where id = v_me.org_id;
  if p_audience not in ('all', 'classes', 'students') then
    raise exception 'BAD_AUDIENCE';
  end if;
  if not p_dry_run and (length(v_body) < 1 or length(v_body) > 600) then
    raise exception 'BAD_BODY';
  end if;

  select coalesce(array_agg(distinct p.id), '{}') into v_students
  from public.profiles p
  where p.org_id = v_org.id and p.role = 'student'
    and case p_audience
          when 'all' then true
          when 'classes' then exists (
            select 1 from public.classroom_students cs
            where cs.student_id = p.id and cs.classroom_id = any (coalesce(p_classrooms, '{}')))
          else p.id = any (coalesce(p_students, '{}'))
        end;

  with ph as (
    select s.sid, (select g.phone from public.guardian_phone_of(s.sid) g) phone
    from unnest(v_students) s(sid)
  )
  select coalesce(array_agg(distinct phone) filter (where phone is not null), '{}'),
         count(*) filter (where phone is null)::int
  into v_phones, v_no_phone
  from ph;

  if p_dry_run then
    return jsonb_build_object('students', cardinality(v_students),
                              'recipients', cardinality(v_phones),
                              'no_phone', v_no_phone);
  end if;
  if cardinality(v_phones) = 0 then
    raise exception 'NO_RECIPIENTS';
  end if;
  if cardinality(v_phones) > 2000 then
    raise exception 'TOO_MANY';
  end if;
  if exists (select 1 from public.sms_broadcasts
             where org_id = v_org.id and created_at > now() - interval '10 minutes') then
    raise exception 'SMS_TOO_SOON';
  end if;

  v_full := v_org.name || ': ' || v_body;
  insert into public.sms_broadcasts (org_id, tenant_id, body, audience, recipients, created_by)
  values (v_org.id, v_org.tenant_id, v_body, p_audience, cardinality(v_phones), v_me.id)
  returning id into v_id;
  insert into public.sms_outbox (tenant_id, org_id, broadcast_id, phone, body, created_by)
  select v_org.tenant_id, v_org.id, v_id, x, v_full, v_me.id
  from unnest(v_phones) x;
  perform public.kick_sms();
  return jsonb_build_object('id', v_id, 'students', cardinality(v_students),
                            'recipients', cardinality(v_phones),
                            'no_phone', v_no_phone);
end;
$$;
revoke all on function public.send_bulk_sms(text, text, uuid[], uuid[], boolean) from public, anon;
grant execute on function public.send_bulk_sms(text, text, uuid[], uuid[], boolean) to authenticated;

-- Geçmiş: gönderim başına durum sayıları.
create or replace function public.my_sms_broadcasts(p_limit int default 30)
returns table (
  id uuid, body text, audience text, recipients int, created_at timestamptz,
  sender text, queued int, sent int, failed int)
language sql stable security definer set search_path = ''
as $$
  select b.id, b.body, b.audience, b.recipients, b.created_at, p.full_name,
         count(*) filter (where o.status = 'queued')::int,
         count(*) filter (where o.status = 'sent')::int,
         count(*) filter (where o.status = 'failed')::int
  from public.sms_broadcasts b
  left join public.profiles p on p.id = b.created_by
  left join public.sms_outbox o on o.broadcast_id = b.id
  where public.is_org_admin(b.org_id)
  group by b.id, p.full_name
  order by b.created_at desc
  limit least(greatest(p_limit, 1), 100)
$$;
revoke all on function public.my_sms_broadcasts(int) from public, anon;
grant execute on function public.my_sms_broadcasts(int) to authenticated;
