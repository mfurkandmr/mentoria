-- Geri alma: 20261105160000_student_books
-- Kitap havuzu, öğrenci kitapları, sınırlar ve çalışma kayıtları silinir
-- (question_logs'a yansıyan satırlar da).
drop function if exists public.import_books(jsonb);
drop function if exists public.topic_gaps(uuid);
drop function if exists public.book_usage(uuid);
drop function if exists public.student_books_overview(uuid, text);
drop function if exists public.set_book_limit(uuid, int, text);
drop function if exists public.reject_book_request(uuid, text);
drop function if exists public.merge_book_request(uuid, uuid);
drop function if exists public.approve_book(uuid);
drop function if exists public.is_book_manager(uuid);

delete from public.question_logs q
using public.book_progress bp where bp.question_log_id = q.id;
drop table if exists public.book_progress;
drop table if exists public.student_book_limits;
drop table if exists public.student_books;
drop table if exists public.books;
drop function if exists public.mirror_book_progress();
drop function if exists public.guard_book_progress();
drop function if exists public.guard_student_book();
drop function if exists public.guard_book();
drop function if exists public.current_term();
drop function if exists public.term_of(date);
drop function if exists public.norm_key(text);

delete from public.notifications where kind = 'book_request';
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement',
                  'inactivity_warning', 'risk_digest', 'installment_due',
                  'timetable'));
