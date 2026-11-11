-- =====================================================================
-- Görüşmeye (ödevlendirmeye) gelmeyen öğrenci: veliye WhatsApp (NOTLAR §93)
-- ---------------------------------------------------------------------
-- Koç haftalık görüşmeyi "öğrenci gelmedi" (missed) diye işaretleyince
-- velinin telefonuna kurumun WhatsApp numarasından bilgi mesajı gider.
--
--  * meeting_occurrences.guardian_notified_at: aynı görüşme için bir kez
--    (işaret kaldırılıp yeniden konsa da ikinci mesaj gitmez).
--  * set_meeting_status artık sonuç döndürür:
--      'notified'  veliye mesaj sıraya alındı
--      'no_phone'  veli telefonu kayıtlı değil
--      null        diğer durumlar (yapıldı / iptal / işaret kaldırma / zaten gitti)
--  * Mesaj kurumun genel şablonuyla gider (kurum_bilgilendirme); Meta'da
--    yeni şablon onayı gerekmez.
--
-- Geri almak için: supabase/rollbacks/20261112110000_meeting_missed_whatsapp.down.sql
-- =====================================================================

alter table public.meeting_occurrences
  add column if not exists guardian_notified_at timestamptz;

drop function if exists public.set_meeting_status(uuid, date, text);
create function public.set_meeting_status(
  p_schedule uuid, p_day date, p_status text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_s       public.meeting_schedules%rowtype;
  v_today   date := (now() at time zone 'Europe/Istanbul')::date;
  v_sent    timestamptz;
  v_org     uuid;
  v_orgname text;
  v_student text;
  v_coach   text;
  v_gname   text;
  v_phone   text;
begin
  select * into v_s from public.meeting_schedules where id = p_schedule;
  if not found or not public.is_coach_of(v_s.student_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if p_status is not null and p_status not in ('held', 'missed', 'cancelled') then
    raise exception 'INVALID_STATUS';
  end if;
  if not public.meeting_occurs_on(v_s.first_date, v_s.repeat_weekly, v_s.until_date, p_day) then
    raise exception 'NO_MEETING_THAT_DAY';
  end if;
  -- Yapıldı / yapılmadı gelecekteki bir gün için işaretlenemez (iptal edilebilir).
  if p_status in ('held', 'missed') and p_day > v_today then
    raise exception 'MEETING_IN_FUTURE';
  end if;

  insert into public.meeting_occurrences
    (schedule_id, occurs_on, student_id, status, marked_by, marked_at)
  values (v_s.id, p_day, v_s.student_id, p_status, auth.uid(), now())
  on conflict (schedule_id, occurs_on) do update
    set status = excluded.status,
        marked_by = excluded.marked_by,
        marked_at = excluded.marked_at
  returning guardian_notified_at into v_sent;

  if p_status is distinct from 'missed' or v_sent is not null then
    return null;
  end if;

  select p.org_id, p.full_name into v_org, v_student
  from public.profiles p where p.id = v_s.student_id;
  select g.guardian_name, g.phone into v_gname, v_phone
  from public.guardian_phone_of(v_s.student_id) g;
  if v_org is null or v_phone is null then
    return 'no_phone';
  end if;
  select name into v_orgname from public.organizations where id = v_org;
  select full_name into v_coach from public.profiles where id = auth.uid();

  insert into public.sms_outbox
    (tenant_id, org_id, student_id, phone, body, created_by)
  values (
    v_s.tenant_id, v_org, v_s.student_id, v_phone,
    format('Sayın %s, %s: öğrenciniz %s, %s günü saat %s için planlanan koç görüşmesine (ödevlendirme) gelmedi. Koçu: %s. Bilgilerinize.',
           coalesce(nullif(trim(v_gname), ''), 'Veli'), v_orgname, v_student,
           to_char(p_day, 'DD.MM.YYYY'), to_char(v_s.start_time, 'HH24:MI'),
           coalesce(nullif(trim(v_coach), ''), v_orgname)),
    auth.uid());
  update public.meeting_occurrences set guardian_notified_at = now()
  where schedule_id = v_s.id and occurs_on = p_day;
  perform public.kick_sms();
  return 'notified';
end;
$$;
revoke execute on function public.set_meeting_status(uuid, date, text) from public, anon;
grant  execute on function public.set_meeting_status(uuid, date, text) to authenticated;
