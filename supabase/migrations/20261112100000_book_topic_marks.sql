-- =====================================================================
-- Kaynak takibi: kitap × konu "bitti" işaretleri (NOTLAR §92)
-- ---------------------------------------------------------------------
-- Öğrencinin her kitabı (kaynağı) için konu konu "bu kitaptan bu konuyu
-- bitirdim" işareti. Ekranda ders başına bir tablo: satırlar konular,
-- sütunlar öğrencinin o dersteki kitapları, hücreler işaret kutusu.
--
--  * book_topic_marks (student_book_id, topic_id): satır varsa bitti.
--  * Okuma: öğrenciyi görebilen herkes (kendisi, koçu, müdürü, velisi).
--  * Yazma yalnızca set_book_topic_mark(kitap, konu, bitti) ile: öğrencinin
--    kendisi ya da onu yöneten koç / müdür. Veli işaretleyemez. Konu
--    kitabın dersine ait olmalı (karma kitapta her konu olur).
--  * Öğrencinin kitabı ya da konu silinince işaretler de silinir.
--
-- Geri almak için: supabase/rollbacks/20261112100000_book_topic_marks.down.sql
-- =====================================================================

create table public.book_topic_marks (
  student_book_id uuid not null references public.student_books (id) on delete cascade,
  topic_id        int  not null references public.topics (id) on delete cascade,
  tenant_id       uuid not null references public.tenants (id),
  student_id      uuid not null references public.profiles (id) on delete cascade,
  marked_by       uuid references public.profiles (id) on delete set null,
  marked_at       timestamptz not null default now(),
  primary key (student_book_id, topic_id)
);
create index on public.book_topic_marks (student_id);
create index on public.book_topic_marks (topic_id);
create index on public.book_topic_marks (tenant_id);
create index on public.book_topic_marks (marked_by);

alter table public.book_topic_marks enable row level security;
create policy "view book topic marks" on public.book_topic_marks
  for select to authenticated using ((select public.can_view_student(student_id)));
create policy "tenant isolation" on public.book_topic_marks as restrictive for all to public
  using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()));
revoke all on public.book_topic_marks from anon;
revoke insert, update, delete, truncate, trigger, references
  on public.book_topic_marks from authenticated;

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
