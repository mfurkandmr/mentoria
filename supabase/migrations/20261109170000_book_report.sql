-- =====================================================================
-- Kitap raporu: hangi öğrenci hangi kitaptan kaç soru çözdü
-- ---------------------------------------------------------------------
-- Müdür kurumun, koç kendi öğrencilerinin dönemlik dökümünü görür
-- (my_managed_students). Kitaptan soru girilmemiş kayıt 0 soru olarak gelir.
--
-- Geri almak için: supabase/rollbacks/20261109170000_book_report.down.sql
-- =====================================================================

create or replace function public.book_question_report(p_term text default null)
returns table (
  student_id     uuid,
  student_name   text,
  student_number text,
  classroom_id   uuid,
  classroom_name text,
  book_id        uuid,
  book_name      text,
  publisher      text,
  subject_code   text,
  status         text,
  questions      int,
  correct        int,
  wrong          int,
  blank          int,
  last_studied   date
)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.full_name, p.student_number, c.id, c.name,
         b.id, b.name, b.publisher, s.code, sb.status,
         coalesce(sum(coalesce(bp.questions,
           coalesce(bp.correct, 0) + coalesce(bp.wrong, 0) + coalesce(bp.blank, 0))), 0)::int,
         coalesce(sum(bp.correct), 0)::int,
         coalesce(sum(bp.wrong), 0)::int,
         coalesce(sum(bp.blank), 0)::int,
         max(bp.studied_on)
  from public.my_managed_students() m(id)
  join public.profiles p on p.id = m.id
  join public.student_books sb on sb.student_id = m.id
    and sb.term = coalesce(nullif(trim(p_term), ''), public.current_term())
  join public.books b on b.id = sb.book_id
  left join public.subjects s on s.id = b.subject_id
  left join public.book_progress bp on bp.student_book_id = sb.id
  left join lateral (
    select cl.id, cl.name
    from public.classroom_students cs
    join public.classrooms cl on cl.id = cs.classroom_id
    where cs.student_id = m.id
    order by cl.name
    limit 1
  ) c on true
  group by p.id, p.full_name, p.student_number, c.id, c.name,
           b.id, b.name, b.publisher, s.code, sb.status
  order by p.full_name, p.id, 11 desc, b.id
$$;
revoke all on function public.book_question_report(text) from public, anon;
grant execute on function public.book_question_report(text) to authenticated;
