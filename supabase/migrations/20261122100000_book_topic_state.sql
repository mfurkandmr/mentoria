-- =====================================================================
-- Kaynak takibi: üç durum (başlanmadı / devam ediyor / bitti)  (NOTLAR §106)
-- ---------------------------------------------------------------------
-- book_topic_marks'a `state` eklenir: 'doing' (sarı) ya da 'done' (yeşil).
-- Satır yok = başlanmadı (gri). Mevcut satırlar 'done' kalır, veri kaybı yok.
--
--  * set_book_topic_state(kitap, konu, durum): durum 'none' | 'doing' | 'done';
--    'none' satırı siler. Yetki ve konu denetimi set_book_topic_mark ile aynı.
--  * Eski set_book_topic_mark(kitap, konu, bitti) korunur (eski uygulama
--    sürümleri çalışsın): true → 'done' yazar, false → siler.
--
-- Geri almak için: supabase/rollbacks/20261122100000_book_topic_state.down.sql
-- =====================================================================

alter table public.book_topic_marks
  add column state text not null default 'done'
  check (state in ('doing', 'done'));

create or replace function public.set_book_topic_state(
  p_student_book uuid, p_topic int, p_state text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  sb        public.student_books%rowtype;
  v_subject smallint;
begin
  if p_state is null or p_state not in ('none', 'doing', 'done') then
    raise exception 'BAD_STATE';
  end if;
  select * into sb from public.student_books where id = p_student_book;
  if sb.id is null
     or (sb.student_id <> auth.uid() and not public.can_manage_student(sb.student_id)) then
    raise exception 'NOT_ALLOWED';
  end if;
  if p_state = 'none' then
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
    (student_book_id, topic_id, tenant_id, student_id, marked_by, state)
  values (sb.id, p_topic, sb.tenant_id, sb.student_id, auth.uid(), p_state)
  on conflict (student_book_id, topic_id)
  do update set state = excluded.state, marked_by = excluded.marked_by,
                marked_at = now();
end;
$$;
revoke all on function public.set_book_topic_state(uuid, int, text) from public, anon;
grant execute on function public.set_book_topic_state(uuid, int, text) to authenticated;

-- Eski işlev: 'bitti' işaretlerken var olan 'doing' satırı da 'done' olur.
create or replace function public.set_book_topic_mark(
  p_student_book uuid, p_topic int, p_done boolean)
returns void
language sql security definer set search_path = ''
as $$
  select public.set_book_topic_state(
    p_student_book, p_topic, case when coalesce(p_done, false) then 'done' else 'none' end);
$$;
revoke all on function public.set_book_topic_mark(uuid, int, boolean) from public, anon;
grant execute on function public.set_book_topic_mark(uuid, int, boolean) to authenticated;
