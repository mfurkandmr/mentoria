-- Geri alma: 20261017110000_tenant_columns
-- (Önce 20261017120000_tenant_isolation.down.sql çalıştırılmalı.)
do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'invite_codes', 'coach_students', 'parent_students', 'exams',
    'exam_subject_results', 'exam_wrong_topics', 'question_logs',
    'topic_progress', 'study_sessions', 'goals', 'tasks', 'coach_notes',
    'assignments', 'assignment_items', 'notifications'
  ] loop
    execute format('drop trigger if exists set_tenant_id on public.%I', t);
    execute format('alter table public.%I drop column if exists tenant_id', t);
  end loop;
end;
$$;

drop function if exists public.set_tenant_id();
drop function if exists public.my_tenant_active();
drop function if exists public.my_tenant();
