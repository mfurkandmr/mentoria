-- 20261107120000_exam_result_sms geri alma.
drop function if exists public.set_exam_result_sms(boolean);
drop function if exists public.exam_result_sms_enabled();

-- _rank_key eski hâline (SMS'siz).
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
end;
$$;
revoke all on function public._rank_key(uuid) from public, anon, authenticated;

drop function if exists public._queue_exam_result_sms(uuid);
drop index if exists public.sms_outbox_exam_once;
alter table public.sms_outbox drop column if exists exam_id;
alter table public.organizations drop column if exists exam_result_sms;
