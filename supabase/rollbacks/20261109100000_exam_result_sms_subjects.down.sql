-- 20261109100000_exam_result_sms_subjects geri alma: ders satırları olmadan.
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
