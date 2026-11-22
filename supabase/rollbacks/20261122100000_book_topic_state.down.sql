-- 20261122100000_book_topic_state geri alma: devam eden (sarı) işaretler silinir,
-- yeşiller kalır; eski set_book_topic_mark gövdesi geri yüklenir.
drop function if exists public.set_book_topic_state(uuid, int, text);

delete from public.book_topic_marks where state = 'doing';
alter table public.book_topic_marks drop column state;

create or replace function public.set_book_topic_mark(
  p_student_book uuid, p_topic int, p_done boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  sb        public.student_books%rowtype;
  v_subject smallint;
begin
  select * into sb from public.student_books where id = p_student_book;
  if sb.id is null
     or (sb.student_id <> auth.uid() and not public.can_manage_student(sb.student_id)) then
    raise exception 'NOT_ALLOWED';
  end if;
  if not coalesce(p_done, false) then
    delete from public.book_topic_marks
    where student_book_id = sb.id and topic_id = p_topic;
    return;
  end if;
  select b.subject_id into v_subject from public.books b where b.id = sb.book_id;
  if not exists (select 1 from public.topics t
                 where t.id = p_topic
                   and (v_subject is null or t.subject_id = v_subject)) then
    raise exception 'BAD_TOPIC';
  end if;
  insert into public.book_topic_marks
    (student_book_id, topic_id, tenant_id, student_id, marked_by)
  values (sb.id, p_topic, sb.tenant_id, sb.student_id, auth.uid())
  on conflict do nothing;
end;
$$;
revoke all on function public.set_book_topic_mark(uuid, int, boolean) from public, anon;
grant execute on function public.set_book_topic_mark(uuid, int, boolean) to authenticated;
