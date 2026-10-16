-- =====================================================================
-- Koç paneli için:
--  * Öğrenci / okul numarası (deneme dosyası eşleştirmesi bunun üzerinden)
--  * Denemeleri artık öğrenci değil koç (veya kurum müdürü) yazar;
--    öğrenci yalnızca okur.
--  * Koçun öğrenci listesi için özet fonksiyonu
-- =====================================================================

-- ---------------------------------------------------------------------
-- Okul numarası: kurum içinde benzersiz, yalnızca koç / müdür değiştirir
-- ---------------------------------------------------------------------
alter table public.profiles add column student_number text;
create unique index profiles_org_student_number_key
  on public.profiles (org_id, student_number)
  where student_number is not null;

create or replace function public.can_manage_student(p_student uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$ select public.is_coach_of(p_student) or public.is_admin_of_user(p_student) $$;

create or replace function public.set_student_number(p_student uuid, p_number text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_number text := nullif(upper(trim(p_number)), '');
begin
  if not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_number is not null and v_number !~ '^[0-9A-Z-]{1,20}$' then
    raise exception 'INVALID_NUMBER';
  end if;
  update public.profiles
  set student_number = v_number
  where id = p_student and role = 'student';
exception
  when unique_violation then
    raise exception 'NUMBER_TAKEN';
end;
$$;

-- ---------------------------------------------------------------------
-- Denemeler: kim girdi, nereden geldi
-- ---------------------------------------------------------------------
alter table public.exams
  add column created_by uuid default auth.uid()
    references public.profiles (id) on delete set null,
  add column source text not null default 'manual'
    check (source in ('manual', 'import'));
create index on public.exams (created_by);

drop policy "student inserts exams"             on public.exams;
drop policy "student updates exams"             on public.exams;
drop policy "student deletes exams"             on public.exams;
drop policy "student inserts exam results"      on public.exam_subject_results;
drop policy "student updates exam results"      on public.exam_subject_results;
drop policy "student deletes exam results"      on public.exam_subject_results;
drop policy "student inserts exam wrong topics" on public.exam_wrong_topics;
drop policy "student updates exam wrong topics" on public.exam_wrong_topics;
drop policy "student deletes exam wrong topics" on public.exam_wrong_topics;

create policy "coach inserts exams" on public.exams
  for insert to authenticated with check (public.can_manage_student(student_id));
create policy "coach updates exams" on public.exams
  for update to authenticated
  using (public.can_manage_student(student_id))
  with check (public.can_manage_student(student_id));
create policy "coach deletes exams" on public.exams
  for delete to authenticated using (public.can_manage_student(student_id));

create policy "coach inserts exam results" on public.exam_subject_results
  for insert to authenticated with check (
    exists (select 1 from public.exams e
            where e.id = exam_id and public.can_manage_student(e.student_id))
  );
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

create policy "coach inserts exam wrong topics" on public.exam_wrong_topics
  for insert to authenticated with check (
    exists (select 1 from public.exams e
            where e.id = exam_id and public.can_manage_student(e.student_id))
  );
create policy "coach updates exam wrong topics" on public.exam_wrong_topics
  for update to authenticated
  using (exists (select 1 from public.exams e
                 where e.id = exam_id and public.can_manage_student(e.student_id)))
  with check (exists (select 1 from public.exams e
                      where e.id = exam_id and public.can_manage_student(e.student_id)));
create policy "coach deletes exam wrong topics" on public.exam_wrong_topics
  for delete to authenticated using (
    exists (select 1 from public.exams e
            where e.id = exam_id and public.can_manage_student(e.student_id))
  );

-- ---------------------------------------------------------------------
-- Koçun öğrenci listesi: numara, deneme sayısı, son deneme
-- (SECURITY INVOKER: RLS geçerli, koç yalnızca kendi öğrencilerini görür)
-- ---------------------------------------------------------------------
create or replace function public.coach_student_summaries()
returns table (
  student_id      uuid,
  full_name       text,
  student_number  text,
  exam_count      int,
  last_exam_name  text,
  last_exam_type  public.exam_type,
  last_total_net  numeric,
  last_taken_on   date
)
language sql stable security invoker set search_path = ''
as $$
  select p.id,
         p.full_name,
         p.student_number,
         (select count(*)::int from public.exams e where e.student_id = p.id),
         le.name,
         le.exam_type,
         le.total_net,
         le.taken_on
  from public.coach_students cs
  join public.profiles p on p.id = cs.student_id
  left join lateral (
    select e.name, e.exam_type, e.taken_on,
           (select coalesce(sum(r.net), 0)
            from public.exam_subject_results r
            where r.exam_id = e.id) as total_net
    from public.exams e
    where e.student_id = p.id
    order by e.taken_on desc, e.created_at desc
    limit 1
  ) le on true
  where cs.coach_id = (select auth.uid())
  order by p.full_name
$$;

revoke execute on function public.can_manage_student(uuid)        from public, anon;
revoke execute on function public.set_student_number(uuid, text)  from public, anon;
revoke execute on function public.coach_student_summaries()       from public, anon;
grant  execute on function public.can_manage_student(uuid)        to authenticated;
grant  execute on function public.set_student_number(uuid, text)  to authenticated;
grant  execute on function public.coach_student_summaries()       to authenticated;
