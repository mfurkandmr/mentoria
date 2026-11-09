-- =====================================================================
-- Sınav sonucu SMS'inde kısa ders satırları
-- ---------------------------------------------------------------------
-- "<Kurum>: <Öğrenci> - <Sınav> sonucu: 72,25 net, kurum sırası 12/240.
--  Tür 30D 5Y 28,75; Mat 22D 3Y 21,25. Ayrıntılar uygulamada."
-- TYT'de 9 ders olduğu için uzun biçim yaklaşık 3 SMS tutuyordu; bu biçim
-- yaklaşık 2 SMS tutar. Listede olmayan yeni bir ders adının ilk 3 harfiyle
-- yazılır.
--
-- Geri almak için: supabase/rollbacks/20261109110000_exam_result_sms_short.down.sql
-- =====================================================================

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
              || '.'
              || coalesce(' ' || d.lines || '.', '')
              || ' Ayrıntılar uygulamada.', 800),
         e.created_by
  from public.exams e
  join public.profiles p on p.id = e.student_id
  cross join lateral (select x.phone from public.guardian_phone_of(e.student_id) x limit 1) g
  cross join lateral (
    select string_agg(
             case s.code
               when 'TYT_TUR' then 'Tür'
               when 'TYT_TAR' then 'Tar'
               when 'TYT_COG' then 'Coğ'
               when 'TYT_FEL' then 'Fel'
               when 'TYT_DIN' then 'Din'
               when 'TYT_MAT' then 'Mat'
               when 'TYT_FIZ' then 'Fiz'
               when 'TYT_KIM' then 'Kim'
               when 'TYT_BIY' then 'Biy'
               when 'AYT_MAT' then 'Mat'
               when 'AYT_FIZ' then 'Fiz'
               when 'AYT_KIM' then 'Kim'
               when 'AYT_BIY' then 'Biy'
               when 'AYT_EDB' then 'Edb'
               when 'AYT_TAR1' then 'Tar1'
               when 'AYT_COG1' then 'Coğ1'
               when 'AYT_TAR2' then 'Tar2'
               when 'AYT_COG2' then 'Coğ2'
               when 'AYT_FELG' then 'Fel'
               when 'AYT_DIN' then 'Din'
               when 'YDT_YD' then 'YD'
               else left(s.name, 3)
             end
               || ' ' || r.correct || 'D ' || r.wrong || 'Y '
               || replace(to_char(r.net, 'FM9990.00'), '.', ','),
             '; ' order by s.sort) lines
    from public.exam_subject_results r
    join public.subjects s on s.id = r.subject_id
    where r.exam_id = e.id) d
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
