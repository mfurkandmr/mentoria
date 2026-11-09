-- =====================================================================
-- Kurum sınavı sonucu velilere SMS
-- ---------------------------------------------------------------------
--  * Kurum sınavı (answer_keys) yayınlanınca ve yayındaki sınava yeni optik
--    gelince (Excel içe aktarma, kamera okuması) her öğrencinin velisine
--    sonuç SMS'i sıraya girer: "<Kurum>: <Öğrenci> - <Sınav> sonucu: 72,25
--    net, kurum sırası 12/240. Ayrıntılar uygulamada."
--  * Tek nokta: _rank_key (sıralamalar yazıldıktan sonra), böylece SMS'te
--    kurum sırası doğru olur.
--  * Her deneme için bir kez (sms_outbox.exam_id tekil). Anahtar düzeltilip
--    yeniden puanlanınca tekrar gitmez. Yalnızca son 3 günde oluşan
--    denemeler: ayar sonradan açılırsa eski sınavlar için toplu SMS çıkmaz.
--  * Numara guardian_phone_of (yoklamadaki veli telefonu, yoksa finanstaki
--    ödeyen). Numarası olmayan öğrenci atlanır.
--  * organizations.exam_result_sms (varsayılan açık): müdür SMS ekranından
--    kapatabilir. exam_result_sms_enabled() / set_exam_result_sms().
--  SMS sağlayıcısı bağlanana kadar mesajlar sırada bekler (send-sms).
--
-- Geri almak için: supabase/rollbacks/20261107120000_exam_result_sms.down.sql
-- =====================================================================

alter table public.organizations
  add column exam_result_sms boolean not null default true;

alter table public.sms_outbox
  add column exam_id uuid references public.exams (id) on delete set null;
create unique index sms_outbox_exam_once on public.sms_outbox (exam_id)
  where exam_id is not null;

create or replace function public._queue_exam_result_sms(p_key uuid)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_key   public.answer_keys%rowtype;
  v_org   public.organizations%rowtype;
  v_total int;
  v_n     int;
begin
  select * into v_key from public.answer_keys where id = p_key;
  if not found or v_key.status <> 'published' then
    return 0;
  end if;
  select * into v_org from public.organizations where id = v_key.org_id;
  if not found or not v_org.exam_result_sms then
    return 0;
  end if;
  select count(*)::int into v_total
  from public.exams where batch_id = p_key and source = 'optic';

  insert into public.sms_outbox (tenant_id, org_id, exam_id, phone, body, created_by)
  select v_key.tenant_id, v_key.org_id, e.id, g.phone,
         left(v_org.name || ': ' || p.full_name || ' - ' || v_key.name || ' sonucu: '
              || replace(to_char(coalesce(e.total_net, 0), 'FM9990.00'), '.', ',') || ' net'
              || case when e.rank_org is not null
                      then ', kurum sırası ' || e.rank_org || '/' || v_total
                      else '' end
              || '. Ayrıntılar uygulamada.', 600),
         e.created_by
  from public.exams e
  join public.profiles p on p.id = e.student_id
  cross join lateral (select x.phone from public.guardian_phone_of(e.student_id) x limit 1) g
  where e.batch_id = p_key and e.source = 'optic'
    and e.created_at > now() - interval '3 days'
    and g.phone is not null
    and not exists (select 1 from public.sms_outbox o where o.exam_id = e.id)
  on conflict (exam_id) where exam_id is not null do nothing;
  get diagnostics v_n = row_count;
  if v_n > 0 then
    perform public.kick_sms();
  end if;
  return v_n;
end;
$$;
revoke all on function public._queue_exam_result_sms(uuid) from public, anon, authenticated;

-- Kurum ve sınıf sıralaması (toplam net ve ders neti); ardından sonuç SMS'i.
create or replace function public._rank_key(p_key uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  perform set_config('mentoria.scoring', 'on', true);
  update public.exams e
  set rank_org = r.ro, rank_class = r.rc
  from (select x.id,
               rank() over (order by x.total_net desc nulls last) ro,
               case when x.classroom_id is null then null
                    else rank() over (partition by x.classroom_id
                                      order by x.total_net desc nulls last) end rc
        from public.exams x where x.batch_id = p_key and x.source = 'optic') r
  where e.id = r.id;
  update public.exam_subject_results t
  set rank_org = r.ro, rank_class = r.rc
  from (select x.exam_id, x.subject_id,
               rank() over (partition by x.subject_id order by x.net desc) ro,
               case when e.classroom_id is null then null
                    else rank() over (partition by x.subject_id, e.classroom_id
                                      order by x.net desc) end rc
        from public.exam_subject_results x
        join public.exams e on e.id = x.exam_id
        where e.batch_id = p_key and e.source = 'optic') r
  where t.exam_id = r.exam_id and t.subject_id = r.subject_id;
  perform public._queue_exam_result_sms(p_key);
end;
$$;
revoke all on function public._rank_key(uuid) from public, anon, authenticated;

create or replace function public.exam_result_sms_enabled()
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_on boolean;
begin
  select o.exam_result_sms into v_on
  from public.profiles p join public.organizations o on o.id = p.org_id
  where p.id = auth.uid() and p.role = 'admin';
  if not found then
    raise exception 'NOT_ALLOWED';
  end if;
  return v_on;
end;
$$;
revoke all on function public.exam_result_sms_enabled() from public, anon;
grant execute on function public.exam_result_sms_enabled() to authenticated;

create or replace function public.set_exam_result_sms(p_enabled boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid;
begin
  select org_id into v_org from public.profiles
  where id = auth.uid() and role = 'admin';
  if v_org is null then
    raise exception 'NOT_ALLOWED';
  end if;
  update public.organizations set exam_result_sms = coalesce(p_enabled, true)
  where id = v_org;
end;
$$;
revoke all on function public.set_exam_result_sms(boolean) from public, anon;
grant execute on function public.set_exam_result_sms(boolean) to authenticated;
