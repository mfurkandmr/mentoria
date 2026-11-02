-- =====================================================================
-- Veli haftalık özeti (tek kart)
-- ---------------------------------------------------------------------
-- Dershanelerin en çok vakit kaybettiği yer veli telefonları: "Bu hafta
-- nasıldı?" sorusunun cevabı tek kartta.
--  * weekly_summary_data(öğrenci): son 7 gün (TR) — çalıştığı gün, kaçırılan
--    / yapılan koç görüşmesi, ödev tamamlama, son deneme neti ve bir önceki
--    aynı türdeki denemeye göre değişim, soru ve odak dakikası. İç fonksiyon;
--    istemci çağıramaz.
--  * weekly_summary(öğrenci): öğrenciyi görebilen (kendisi, velisi, koçu,
--    müdürü) için aynı veri. Kart ve WhatsApp metni bundan üretilir.
--  * send_parent_weekly_reports(): pazar akşamı bildirimi artık aynı veriyi
--    taşır (eski alanlar questions / minutes / days korunur).
--  * "Devamsızlık": uygulamada sınıf yoklaması yok; kartta çalışmadığı gün ve
--    kaçırılan koç görüşmesi gösterilir.
--
-- Geri almak için: supabase/rollbacks/20261031120000_weekly_summary.down.sql
-- =====================================================================

create or replace function public.weekly_summary_data(
  p_student uuid, p_now timestamptz default now())
returns jsonb
language sql stable security definer set search_path = ''
as $$
  with bounds as (
    select (p_now at time zone 'Europe/Istanbul')::date as d_end,
           (p_now at time zone 'Europe/Istanbul')::date - 6 as d_start
  ), q as (
    select coalesce(sum(l.correct + l.wrong + l.blank), 0)::int as total
    from public.question_logs l, bounds b
    where l.student_id = p_student and l.logged_on between b.d_start and b.d_end
  ), m as (
    select coalesce(sum(s.duration_sec) / 60, 0)::int as minutes
    from public.study_sessions s, bounds b
    where s.student_id = p_student
      and (s.started_at at time zone 'Europe/Istanbul')::date between b.d_start and b.d_end
  ), d as (
    select count(distinct x.day)::int as days from (
      select l.logged_on as day from public.question_logs l, bounds b
      where l.student_id = p_student and l.logged_on between b.d_start and b.d_end
        and l.correct + l.wrong + l.blank > 0
      union
      select (s.started_at at time zone 'Europe/Istanbul')::date
      from public.study_sessions s, bounds b
      where s.student_id = p_student
        and (s.started_at at time zone 'Europe/Istanbul')::date between b.d_start and b.d_end
    ) x
  ), mt as (
    select count(*) filter (where o.status = 'held')::int as held,
           count(*) filter (where o.status = 'missed')::int as missed
    from public.meeting_occurrences o, bounds b
    where o.student_id = p_student and o.occurs_on between b.d_start and b.d_end
  ), hw as (
    -- Bu hafta teslim günü olan (teslim günü yoksa bu hafta verilen) ödevler.
    select count(i.id)::int as total,
           count(i.id) filter (where i.done)::int as done
    from public.assignments a
    join public.assignment_items i on i.assignment_id = a.id, bounds b
    where a.student_id = p_student
      and coalesce(a.due_on, (a.created_at at time zone 'Europe/Istanbul')::date)
          between b.d_start and b.d_end
  ), ex as (
    select e.exam_type::text as exam_type, e.name, e.taken_on,
           (select coalesce(sum(r.net), 0) from public.exam_subject_results r
            where r.exam_id = e.id) as net,
           row_number() over (partition by e.exam_type
                              order by e.taken_on desc, e.created_at desc) as rn
    from public.exams e
    where e.student_id = p_student
  ), last_exam as (
    select * from ex where rn = 1 order by taken_on desc limit 1
  ), prev_exam as (
    select ex.net from ex join last_exam l on l.exam_type = ex.exam_type
    where ex.rn = 2
  )
  select jsonb_build_object(
    'from', b.d_start, 'to', b.d_end,
    'questions', q.total, 'minutes', m.minutes, 'days', d.days,
    'meetings_held', mt.held, 'meetings_missed', mt.missed,
    'homework_total', hw.total, 'homework_done', hw.done,
    'exam_type', le.exam_type, 'exam_name', le.name, 'exam_on', le.taken_on,
    'last_net', le.net, 'prev_net', (select net from prev_exam))
  from bounds b, q, m, d, mt, hw
  left join last_exam le on true
$$;
revoke all on function public.weekly_summary_data(uuid, timestamptz) from public, anon, authenticated;

create or replace function public.weekly_summary(p_student uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.can_view_student(p_student) or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  return public.weekly_summary_data(p_student);
end;
$$;
revoke execute on function public.weekly_summary(uuid) from public, anon;
grant execute on function public.weekly_summary(uuid) to authenticated;

-- Pazar akşamı bildirimi: kartla aynı veri.
create or replace function public.send_parent_weekly_reports(p_now timestamptz default now())
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_n int;
begin
  insert into public.notifications (user_id, kind, data, ref_id)
  select ps.parent_id, 'weekly_report',
         public.weekly_summary_data(ps.student_id, p_now)
           || jsonb_build_object(
                'child', split_part(s.full_name, ' ', 1),
                'child_id', ps.student_id,
                'route', '/parent/child/' || ps.student_id || '?tab=4'),
         ps.student_id
  from public.parent_students ps
  join public.profiles s on s.id = ps.student_id
  join public.tenants t on t.id = s.tenant_id and t.is_active
  left join public.organizations o on o.id = s.org_id
  -- Lisansı biten kurumun velisine rapor gitmez.
  where (o.license_expires_at is null or o.license_expires_at > p_now)
    and not exists (
      select 1 from public.notifications n
      where n.user_id = ps.parent_id and n.kind = 'weekly_report'
        and n.ref_id = ps.student_id
        and n.created_at > p_now - interval '5 days');
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.send_parent_weekly_reports(timestamptz) from public, anon, authenticated;
