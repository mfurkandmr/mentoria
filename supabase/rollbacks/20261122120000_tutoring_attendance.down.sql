-- 20261122120000_tutoring_attendance geri alma.
drop function if exists public.my_tutoring_history(integer);
drop function if exists public.teacher_tutoring_history(integer);
drop function if exists public.mark_tutoring_attendance(uuid, boolean);
alter table public.tutoring_requests drop column if exists attended;
