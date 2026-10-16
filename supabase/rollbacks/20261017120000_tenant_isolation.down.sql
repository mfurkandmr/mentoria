-- Geri alma: 20261017120000_tenant_isolation
do $$
declare
  t text;
begin
  foreach t in array array[
    'organizations', 'profiles',
    'invite_codes', 'coach_students', 'parent_students', 'exams',
    'exam_subject_results', 'exam_wrong_topics', 'question_logs',
    'topic_progress', 'study_sessions', 'goals', 'tasks', 'coach_notes',
    'assignments', 'assignment_items', 'notifications'
  ] loop
    execute format('drop policy if exists "tenant isolation" on public.%I', t);
  end loop;
end;
$$;
