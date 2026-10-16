-- Geri alma: 20261017230000_exam_batches
-- Paketler ve 7 günlük kilit kalkar; koç yine öğrencisinin her denemesini
-- düzenleyip silebilir.
drop function if exists public.delete_exam_batch(uuid);
drop function if exists public.my_exam_batches(int, int);

drop policy if exists "coach updates exam results" on public.exam_subject_results;
drop policy if exists "coach deletes exam results" on public.exam_subject_results;
create policy "coach updates exam results" on public.exam_subject_results
  for update to authenticated
  using (exists (select 1 from public.exams e
                 where e.id = exam_id and public.can_manage_student(e.student_id)))
  with check (exists (select 1 from public.exams e
                      where e.id = exam_id and public.can_manage_student(e.student_id)));
create policy "coach deletes exam results" on public.exam_subject_results
  for delete to authenticated using (
    exists (select 1 from public.exams e
            where e.id = exam_id and public.can_manage_student(e.student_id))
  );

drop policy if exists "coach updates exams" on public.exams;
drop policy if exists "coach deletes exams" on public.exams;
create policy "coach updates exams" on public.exams
  for update to authenticated
  using (public.can_manage_student(student_id))
  with check (public.can_manage_student(student_id));
create policy "coach deletes exams" on public.exams
  for delete to authenticated using (public.can_manage_student(student_id));

drop function if exists public.exam_editable(timestamptz);

drop index if exists public.exams_created_by_batch_id_idx;
alter table public.exams drop column if exists batch_id;
