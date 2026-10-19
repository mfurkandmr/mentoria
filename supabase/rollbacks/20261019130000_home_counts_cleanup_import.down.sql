-- Geri al: 20261019130000_home_counts_cleanup_import.sql

drop function if exists public.import_exam_batch(uuid, jsonb, jsonb);

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'cleanup-notifications') then
      perform cron.unschedule('cleanup-notifications');
    end if;
  end if;
end;
$$;
drop function if exists public.cleanup_old_notifications(int);

-- student_home: 'shortcuts'suz 3 parametreli sürüme dön.
drop function if exists public.student_home(uuid, date, timestamptz, date);
create or replace function public.student_home(
  p_student uuid,
  p_since date,
  p_since_ts timestamptz
) returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'logs', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', l.id,
          'correct', l.correct,
          'wrong', l.wrong,
          'blank', l.blank,
          'logged_on', l.logged_on,
          'source', l.source,
          'topic_id', l.topic_id,
          'subjects', jsonb_build_object('code', s.code),
          'topics', case when t.id is null then null
                         else jsonb_build_object('name', t.name) end
        ) order by l.logged_on desc, l.created_at desc)
      from question_logs l
      join subjects s on s.id = l.subject_id
      left join topics t on t.id = l.topic_id
      where l.student_id = p_student and l.logged_on >= p_since
    ), '[]'::jsonb),

    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', ss.id,
          'type', ss.type,
          'started_at', ss.started_at,
          'duration_sec', ss.duration_sec,
          'subjects', case when s.id is null then null
                           else jsonb_build_object('code', s.code) end
        ) order by ss.started_at desc)
      from study_sessions ss
      left join subjects s on s.id = ss.subject_id
      where ss.student_id = p_student and ss.started_at >= p_since_ts
    ), '[]'::jsonb),

    'goals', (select to_jsonb(g) from goals g where g.student_id = p_student),

    'topic_progress', coalesce((
      select jsonb_agg(jsonb_build_object(
          'topic_id', tp.topic_id, 'status', tp.status))
      from topic_progress tp
      where tp.student_id = p_student
    ), '[]'::jsonb),

    'exams', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', e.id,
          'exam_type', e.exam_type,
          'field', e.field,
          'name', e.name,
          'publisher', e.publisher,
          'taken_on', e.taken_on,
          'created_at', e.created_at,
          'exam_subject_results', coalesce((
            select jsonb_agg(jsonb_build_object(
                'correct', r.correct,
                'wrong', r.wrong,
                'blank', r.blank,
                'subjects', jsonb_build_object('code', s.code)))
            from exam_subject_results r
            join subjects s on s.id = r.subject_id
            where r.exam_id = e.id
          ), '[]'::jsonb)
        ) order by e.taken_on desc, e.created_at desc)
      from exams e
      where e.student_id = p_student
    ), '[]'::jsonb),

    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'title', a.title,
          'note', a.note,
          'due_on', a.due_on,
          'created_at', a.created_at,
          'coach', case when c.id is null then null
                        else jsonb_build_object('full_name', c.full_name) end,
          'assignment_items', coalesce((
            select jsonb_agg(jsonb_build_object(
                'id', i.id,
                'question_count', i.question_count,
                'note', i.note,
                'sort', i.sort,
                'done', i.done,
                'subjects', jsonb_build_object('code', s.code),
                'topics', case when t.id is null then null
                               else jsonb_build_object('id', t.id, 'name', t.name) end))
            from assignment_items i
            join subjects s on s.id = i.subject_id
            left join topics t on t.id = i.topic_id
            where i.assignment_id = a.id
          ), '[]'::jsonb)
        ) order by a.created_at desc)
      from assignments a
      left join profiles c on c.id = a.coach_id
      where a.student_id = p_student
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.student_home(uuid, date, timestamptz) from public, anon;
grant execute on function public.student_home(uuid, date, timestamptz) to authenticated;

drop function if exists public.student_shortcut_counts(uuid, date);
