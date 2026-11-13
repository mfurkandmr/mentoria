-- =====================================================================
-- Ödev PDF'i ve koçun mesajı veliye WhatsApp'tan (NOTLAR §89)
-- ---------------------------------------------------------------------
-- Kurumun isteği: her ödev PDF olarak anında veliye gitsin; mesajda koçun
-- (ödevi verenin) ve öğrencinin adı olsun. Koçun veliye yazdığı mesaj da
-- kurumun WhatsApp numarasından gitsin.
--
--  * homework kovası (özel, yalnızca PDF, 5 MB): yol
--    '<kurum_id>/<ödev_id>.pdf'. Uygulama ödevi gönderdikten sonra PDF'i
--    kendisi üretip yükler; yükleme yalnızca o ödevi yönetebilen kişiye açık.
--  * queue_homework_whatsapp(ödev): veli telefonuna `odev_bildirimi`
--    şablonuyla PDF ekli mesaj. Her ödev için bir kez. Dosya yolunu sunucu
--    kurar (istemcinin verdiği yol kullanılmaz).
--  * send_guardian_message(öğrenci, metin): koç / müdür → veli,
--    `koc_mesaji` şablonu. Öğrenci başına 24 saatte en çok 5.
--  * guardian_messages(öğrenci): o öğrencinin velisine giden son mesajlar
--    ve durumu (gönderildi / okundu / gitmedi).
--  * sms_outbox.student_id, assignment_id: mesajın kime / hangi ödeve ait
--    olduğu. Öğrenci silinince mesaj kayıtları da silinir.
--  * PDF'ler 80 gün sonra depodan silinir (mesaj kaydı 90 günde silinir).
--
-- Şablon metinleri: docs/WHATSAPP_KURULUM.md.
--
-- Geri almak için: supabase/rollbacks/20261111140000_homework_whatsapp.down.sql
-- =====================================================================

alter table public.sms_outbox
  add column if not exists student_id uuid references public.profiles (id) on delete cascade,
  add column if not exists assignment_id uuid references public.assignments (id) on delete set null;
create index if not exists sms_outbox_student_id on public.sms_outbox (student_id, created_at desc);
create unique index if not exists sms_outbox_assignment_once
  on public.sms_outbox (assignment_id) where assignment_id is not null;

-- Bu ödevi (öğrencisini) yönetebiliyor muyum?
create or replace function public.can_manage_assignment(p_assignment uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.assignments a
    where a.id = p_assignment and public.can_manage_student(a.student_id))
$$;
revoke all on function public.can_manage_assignment(uuid) from public, anon;
grant execute on function public.can_manage_assignment(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Kova
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'storage') then
    raise notice 'storage şeması yok, ödev kovası atlandı';
    return;
  end if;

  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('homework', 'homework', false, 5242880, array['application/pdf'])
  on conflict (id) do update
    set public = excluded.public,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

  -- '<kurum>/<ödev>.pdf': kendi kurumu ve yönetebildiği öğrencinin ödevi.
  execute $p$
    create policy "manager uploads homework pdf" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'homework'
                  and (storage.foldername(name))[1] = (select public.my_org())::text
                  and storage.filename(name) ~ '^[0-9a-f-]{36}\.pdf$'
                  and public.can_manage_assignment(split_part(storage.filename(name), '.', 1)::uuid))
  $p$;
  execute $p$
    create policy "manager reads homework pdf" on storage.objects
      for select to authenticated
      using (bucket_id = 'homework'
             and (storage.foldername(name))[1] = (select public.my_org())::text
             and storage.filename(name) ~ '^[0-9a-f-]{36}\.pdf$'
             and public.can_manage_assignment(split_part(storage.filename(name), '.', 1)::uuid))
  $p$;
end;
$$;

-- Depoda dosya var mı (yerel testte storage yok: var sayılır).
create or replace function public._homework_pdf_exists(p_path text)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v boolean;
begin
  if not exists (select 1 from pg_namespace where nspname = 'storage') then
    return true;
  end if;
  execute 'select exists (select 1 from storage.objects where bucket_id = ''homework'' and name = $1)'
    into v using p_path;
  return v;
end;
$$;
revoke all on function public._homework_pdf_exists(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Ödev → veli
-- ---------------------------------------------------------------------
-- Dönüş: 'queued' | 'already' (bu ödev zaten gönderildi) | 'no_phone'.
create or replace function public.queue_homework_whatsapp(p_assignment uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  a        public.assignments%rowtype;
  v_org    uuid;
  v_tenant uuid;
  v_orgname text;
  v_student text;
  v_sender text;
  v_phone  text;
  v_path   text;
  v_due    text;
begin
  select * into a from public.assignments where id = p_assignment;
  if a.id is null or not public.can_manage_student(a.student_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if exists (select 1 from public.sms_outbox where assignment_id = a.id) then
    return 'already';
  end if;

  select p.org_id, p.tenant_id, p.full_name into v_org, v_tenant, v_student
  from public.profiles p where p.id = a.student_id;
  if v_org is null then
    return 'no_phone';
  end if;
  select g.phone into v_phone from public.guardian_phone_of(a.student_id) g;
  if v_phone is null then
    return 'no_phone';
  end if;

  v_path := v_org::text || '/' || a.id::text || '.pdf';
  if not public._homework_pdf_exists(v_path) then
    raise exception 'HW_NO_PDF';
  end if;

  select name into v_orgname from public.organizations where id = v_org;
  select full_name into v_sender from public.profiles where id = auth.uid();
  v_sender := coalesce(nullif(trim(v_sender), ''), v_orgname);
  v_due := coalesce(to_char(a.due_on, 'DD.MM.YYYY'), 'belirtilmedi');

  insert into public.sms_outbox
    (tenant_id, org_id, student_id, assignment_id, phone, body, template, params,
     media_path, created_by)
  values (v_tenant, v_org, a.student_id, a.id, v_phone,
          left(format('%s, %s adına ödevlendirme yapmıştır: %s (son tarih %s).',
                      v_sender, v_student, a.title, v_due), 1000),
          'odev_bildirimi',
          jsonb_build_array(v_sender, v_student, a.title, v_due, v_orgname),
          'homework/' || v_path, auth.uid());

  perform public.kick_sms();
  return 'queued';
end;
$$;
revoke all on function public.queue_homework_whatsapp(uuid) from public, anon;
grant execute on function public.queue_homework_whatsapp(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Koç / müdür → veli
-- ---------------------------------------------------------------------
create or replace function public.send_guardian_message(p_student uuid, p_body text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_body    text := trim(coalesce(p_body, ''));
  v_org     uuid;
  v_tenant  uuid;
  v_orgname text;
  v_student text;
  v_sender  text;
  v_phone   text;
begin
  if not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  if length(v_body) not between 1 and 900 then
    raise exception 'BAD_BODY';
  end if;
  if (select count(*) from public.sms_outbox o
      where o.student_id = p_student and o.template = 'koc_mesaji'
        and o.created_at > now() - interval '24 hours') >= 5 then
    raise exception 'GUARDIAN_MSG_LIMIT';
  end if;

  select p.org_id, p.tenant_id, p.full_name into v_org, v_tenant, v_student
  from public.profiles p where p.id = p_student;
  select g.phone into v_phone from public.guardian_phone_of(p_student) g;
  if v_org is null or v_phone is null then
    raise exception 'NO_PHONE';
  end if;
  select name into v_orgname from public.organizations where id = v_org;
  select full_name into v_sender from public.profiles where id = auth.uid();
  v_sender := coalesce(nullif(trim(v_sender), ''), v_orgname);

  insert into public.sms_outbox
    (tenant_id, org_id, student_id, phone, body, template, params, created_by)
  values (v_tenant, v_org, p_student, v_phone, v_body, 'koc_mesaji',
          jsonb_build_array(v_student, v_sender, v_body, v_orgname), auth.uid());

  perform public.kick_sms();
  return 'queued';
end;
$$;
revoke all on function public.send_guardian_message(uuid, text) from public, anon;
grant execute on function public.send_guardian_message(uuid, text) to authenticated;

-- Öğrencinin velisine giden son 30 mesaj (yönetebilen koç / müdür).
create or replace function public.guardian_messages(p_student uuid)
returns table (
  id uuid, kind text, body text, sender text, status text,
  created_at timestamptz, delivered_at timestamptz, read_at timestamptz, error text)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  return query
  select o.id,
         case o.template when 'odev_bildirimi' then 'homework'
                         when 'koc_mesaji' then 'coach' else 'other' end,
         o.body, s.full_name, o.status, o.created_at, o.delivered_at, o.read_at, o.error
  from public.sms_outbox o
  left join public.profiles s on s.id = o.created_by
  where o.student_id = p_student
  order by o.created_at desc
  limit 30;
end;
$$;
revoke all on function public.guardian_messages(uuid) from public, anon;
grant execute on function public.guardian_messages(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Saklama: PDF 80 gün (mesaj kaydı 90 günde silinir).
-- ---------------------------------------------------------------------
create or replace function public.purge_homework_pdfs(p_now timestamptz default now())
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_n int;
begin
  with old as (
    select o.id, substr(o.media_path, length('homework/') + 1) path
    from public.sms_outbox o
    where o.media_path like 'homework/%' and o.created_at < p_now - interval '80 days'
  ), q as (
    insert into public.storage_cleanup (bucket, path)
    select 'homework', old.path from old
    on conflict do nothing
  ), u as (
    update public.sms_outbox o set media_path = null
    from old where o.id = old.id
    returning 1
  )
  select count(*) into v_n from u;
  return v_n;
end;
$$;
revoke all on function public.purge_homework_pdfs(timestamptz) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('homework-pdf-retention', '50 0 * * *',
      'select public.purge_homework_pdfs()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); zamanlanmadı';
  end if;
end $$;
