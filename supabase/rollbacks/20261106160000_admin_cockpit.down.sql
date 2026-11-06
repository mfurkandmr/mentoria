-- 20261106160000_admin_cockpit geri alma.
drop function if exists public.admin_cockpit();
drop function if exists public.notify_coach_about_student(uuid, text);
delete from public.notifications where kind = 'coach_alert';
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest', 'installment_due',
                  'timetable', 'book_request'));
drop function if exists public.set_coach_phone(uuid, text);
drop table if exists public.coach_phones;
drop function if exists public.delete_exam_plan(uuid);
drop function if exists public.add_exam_plan(text, public.exam_type, date);
drop table if exists public.org_exam_plans;
drop function if exists public.touch_last_seen();
alter table public.profiles drop column if exists last_seen_at;
