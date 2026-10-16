-- =====================================================================
-- Supabase denetim (advisor) düzeltmeleri
--  * Yardımcı SECURITY DEFINER fonksiyonları anonim kullanıcıya kapatıldı
--  * guard_task_update için search_path sabitlendi
--  * RLS içinde auth.uid() satır başına değil sorgu başına hesaplanıyor
--  * "for all" politikaları insert/update/delete olarak ayrıldı
--    (SELECT için birden çok izin veren politika kalmasın)
--  * Yabancı anahtarlara indeks eklendi
-- =====================================================================

-- ---------------------------------------------------------------------
-- Fonksiyon yetkileri
-- ---------------------------------------------------------------------
revoke execute on function public.my_role()                 from public, anon;
revoke execute on function public.my_org()                  from public, anon;
revoke execute on function public.is_coach_of(uuid)         from public, anon;
revoke execute on function public.is_admin_of_user(uuid)    from public, anon;
revoke execute on function public.can_view_student(uuid)    from public, anon;
grant  execute on function public.my_role()                 to authenticated;
grant  execute on function public.my_org()                  to authenticated;
grant  execute on function public.is_coach_of(uuid)         to authenticated;
grant  execute on function public.is_admin_of_user(uuid)    to authenticated;
grant  execute on function public.can_view_student(uuid)    to authenticated;

alter function public.guard_task_update() set search_path = '';

-- ---------------------------------------------------------------------
-- Politikalar (yeniden)
-- ---------------------------------------------------------------------
drop policy "org members read"                  on public.organizations;
drop policy "admin renames org"                 on public.organizations;
drop policy "read own and related profiles"     on public.profiles;
drop policy "update own profile"                on public.profiles;
drop policy "read coach links"                  on public.coach_students;
drop policy "admin manages coach links"         on public.coach_students;
drop policy "read parent links"                 on public.parent_students;
drop policy "student removes parent"            on public.parent_students;
drop policy "read own invites"                  on public.invite_codes;
drop policy "delete own invites"                on public.invite_codes;
drop policy "view exams"                        on public.exams;
drop policy "student writes exams"              on public.exams;
drop policy "view exam results"                 on public.exam_subject_results;
drop policy "student writes exam results"       on public.exam_subject_results;
drop policy "view exam wrong topics"            on public.exam_wrong_topics;
drop policy "student writes exam wrong topics"  on public.exam_wrong_topics;
drop policy "view question logs"                on public.question_logs;
drop policy "student writes question logs"      on public.question_logs;
drop policy "view topic progress"               on public.topic_progress;
drop policy "student writes topic progress"     on public.topic_progress;
drop policy "view study sessions"               on public.study_sessions;
drop policy "student writes study sessions"     on public.study_sessions;
drop policy "view goals"                        on public.goals;
drop policy "student or coach writes goals"     on public.goals;
drop policy "view tasks"                        on public.tasks;
drop policy "coach creates tasks"               on public.tasks;
drop policy "coach or student updates tasks"    on public.tasks;
drop policy "coach deletes tasks"               on public.tasks;
drop policy "view coach notes"                  on public.coach_notes;
drop policy "coach writes notes"                on public.coach_notes;
drop policy "coach edits own notes"             on public.coach_notes;
drop policy "coach deletes own notes"           on public.coach_notes;

-- Kurum
create policy "org members read" on public.organizations
  for select to authenticated using (id = (select public.my_org()));
create policy "admin renames org" on public.organizations
  for update to authenticated
  using (id = (select public.my_org()) and (select public.my_role()) = 'admin')
  with check (id = (select public.my_org()));

-- Profiller
create policy "read own and related profiles" on public.profiles
  for select to authenticated using (
    id = (select auth.uid())
    or public.can_view_student(id)
    or exists (
         select 1 from public.coach_students cs
         where cs.coach_id = profiles.id and cs.student_id = (select auth.uid())
       )
    or (org_id = (select public.my_org()) and (select public.my_role()) = 'admin')
  );
create policy "update own profile" on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Koç–öğrenci bağı
create policy "read coach links" on public.coach_students
  for select to authenticated using (
    coach_id = (select auth.uid()) or student_id = (select auth.uid())
    or (org_id = (select public.my_org()) and (select public.my_role()) = 'admin')
  );
create policy "admin adds coach links" on public.coach_students
  for insert to authenticated
  with check (
    org_id = (select public.my_org()) and (select public.my_role()) = 'admin'
    and public.is_admin_of_user(coach_id) and public.is_admin_of_user(student_id)
  );
create policy "admin updates coach links" on public.coach_students
  for update to authenticated
  using (org_id = (select public.my_org()) and (select public.my_role()) = 'admin')
  with check (
    org_id = (select public.my_org()) and (select public.my_role()) = 'admin'
    and public.is_admin_of_user(coach_id) and public.is_admin_of_user(student_id)
  );
create policy "admin removes coach links" on public.coach_students
  for delete to authenticated
  using (org_id = (select public.my_org()) and (select public.my_role()) = 'admin');

-- Veli–öğrenci bağı
create policy "read parent links" on public.parent_students
  for select to authenticated using (
    parent_id = (select auth.uid()) or student_id = (select auth.uid())
    or public.is_coach_of(student_id) or public.is_admin_of_user(student_id)
  );
create policy "student removes parent" on public.parent_students
  for delete to authenticated using (student_id = (select auth.uid()));

-- Davet kodları
create policy "read own invites" on public.invite_codes
  for select to authenticated using (
    created_by = (select auth.uid())
    or (org_id = (select public.my_org()) and (select public.my_role()) = 'admin')
  );
create policy "delete own invites" on public.invite_codes
  for delete to authenticated using (
    created_by = (select auth.uid())
    or (org_id = (select public.my_org()) and (select public.my_role()) = 'admin')
  );

-- Öğrenci verileri: ilgili herkes okur, yalnızca öğrenci yazar.
create policy "view exams" on public.exams
  for select to authenticated using (public.can_view_student(student_id));
create policy "student inserts exams" on public.exams
  for insert to authenticated with check (student_id = (select auth.uid()));
create policy "student updates exams" on public.exams
  for update to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
create policy "student deletes exams" on public.exams
  for delete to authenticated using (student_id = (select auth.uid()));

create policy "view exam results" on public.exam_subject_results
  for select to authenticated using (
    exists (select 1 from public.exams e
            where e.id = exam_id and public.can_view_student(e.student_id))
  );
create policy "student inserts exam results" on public.exam_subject_results
  for insert to authenticated with check (
    exists (select 1 from public.exams e where e.id = exam_id and e.student_id = (select auth.uid()))
  );
create policy "student updates exam results" on public.exam_subject_results
  for update to authenticated
  using (exists (select 1 from public.exams e where e.id = exam_id and e.student_id = (select auth.uid())))
  with check (exists (select 1 from public.exams e where e.id = exam_id and e.student_id = (select auth.uid())));
create policy "student deletes exam results" on public.exam_subject_results
  for delete to authenticated using (
    exists (select 1 from public.exams e where e.id = exam_id and e.student_id = (select auth.uid()))
  );

create policy "view exam wrong topics" on public.exam_wrong_topics
  for select to authenticated using (
    exists (select 1 from public.exams e
            where e.id = exam_id and public.can_view_student(e.student_id))
  );
create policy "student inserts exam wrong topics" on public.exam_wrong_topics
  for insert to authenticated with check (
    exists (select 1 from public.exams e where e.id = exam_id and e.student_id = (select auth.uid()))
  );
create policy "student updates exam wrong topics" on public.exam_wrong_topics
  for update to authenticated
  using (exists (select 1 from public.exams e where e.id = exam_id and e.student_id = (select auth.uid())))
  with check (exists (select 1 from public.exams e where e.id = exam_id and e.student_id = (select auth.uid())));
create policy "student deletes exam wrong topics" on public.exam_wrong_topics
  for delete to authenticated using (
    exists (select 1 from public.exams e where e.id = exam_id and e.student_id = (select auth.uid()))
  );

create policy "view question logs" on public.question_logs
  for select to authenticated using (public.can_view_student(student_id));
create policy "student inserts question logs" on public.question_logs
  for insert to authenticated with check (student_id = (select auth.uid()));
create policy "student updates question logs" on public.question_logs
  for update to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
create policy "student deletes question logs" on public.question_logs
  for delete to authenticated using (student_id = (select auth.uid()));

create policy "view topic progress" on public.topic_progress
  for select to authenticated using (public.can_view_student(student_id));
create policy "student inserts topic progress" on public.topic_progress
  for insert to authenticated with check (student_id = (select auth.uid()));
create policy "student updates topic progress" on public.topic_progress
  for update to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
create policy "student deletes topic progress" on public.topic_progress
  for delete to authenticated using (student_id = (select auth.uid()));

create policy "view study sessions" on public.study_sessions
  for select to authenticated using (public.can_view_student(student_id));
create policy "student inserts study sessions" on public.study_sessions
  for insert to authenticated with check (student_id = (select auth.uid()));
create policy "student updates study sessions" on public.study_sessions
  for update to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
create policy "student deletes study sessions" on public.study_sessions
  for delete to authenticated using (student_id = (select auth.uid()));

-- Hedefler: öğrenci ve koçu yazabilir.
create policy "view goals" on public.goals
  for select to authenticated using (public.can_view_student(student_id));
create policy "student or coach inserts goals" on public.goals
  for insert to authenticated
  with check (student_id = (select auth.uid()) or public.is_coach_of(student_id));
create policy "student or coach updates goals" on public.goals
  for update to authenticated
  using (student_id = (select auth.uid()) or public.is_coach_of(student_id))
  with check (student_id = (select auth.uid()) or public.is_coach_of(student_id));
create policy "student or coach deletes goals" on public.goals
  for delete to authenticated
  using (student_id = (select auth.uid()) or public.is_coach_of(student_id));

-- Görevler
create policy "view tasks" on public.tasks
  for select to authenticated using (public.can_view_student(student_id));
create policy "coach creates tasks" on public.tasks
  for insert to authenticated
  with check (coach_id = (select auth.uid()) and public.is_coach_of(student_id));
create policy "coach or student updates tasks" on public.tasks
  for update to authenticated
  using (coach_id = (select auth.uid()) or student_id = (select auth.uid()))
  with check (coach_id = (select auth.uid()) or student_id = (select auth.uid()));
create policy "coach deletes tasks" on public.tasks
  for delete to authenticated using (coach_id = (select auth.uid()));

-- Koç notları
create policy "view coach notes" on public.coach_notes
  for select to authenticated using (
    coach_id = (select auth.uid()) or student_id = (select auth.uid())
    or public.is_admin_of_user(student_id)
  );
create policy "coach writes notes" on public.coach_notes
  for insert to authenticated
  with check (coach_id = (select auth.uid()) and public.is_coach_of(student_id));
create policy "coach edits own notes" on public.coach_notes
  for update to authenticated
  using (coach_id = (select auth.uid())) with check (coach_id = (select auth.uid()));
create policy "coach deletes own notes" on public.coach_notes
  for delete to authenticated using (coach_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- Yabancı anahtar indeksleri
-- ---------------------------------------------------------------------
create index on public.coach_notes (coach_id);
create index on public.coach_students (org_id);
create index on public.exam_subject_results (subject_id);
create index on public.exam_wrong_topics (topic_id);
create index on public.invite_codes (org_id);
create index on public.invite_codes (coach_id);
create index on public.invite_codes (student_id);
create index on public.invite_codes (created_by);
create index on public.question_logs (subject_id);
create index on public.question_logs (topic_id);
create index on public.score_coefficients (subject_id);
create index on public.study_sessions (subject_id);
create index on public.tasks (coach_id);
create index on public.tasks (subject_id);
create index on public.tasks (topic_id);
create index on public.topic_progress (topic_id);
create index on public.topics (parent_id);
