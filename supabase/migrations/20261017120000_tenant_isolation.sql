-- =====================================================================
-- White label 3/4: Dershaneler arası veri izolasyonu
--
-- Her dershane tablosuna RESTRICTIVE bir politika eklenir. Restrictive
-- politikalar mevcut (permissive) politikalarla VE'lenir: mevcut kurallardan
-- biri yanlışlıkla fazla izin verse bile, kullanıcı yalnızca kendi
-- dershanesinin satırlarını görebilir/yazabilir. Dershane pasifse veri
-- tablolarına erişim kapanır (profil ve dershane kaydı okunabilir kalır ki
-- uygulama "erişim durduruldu" ekranını gösterebilsin).
--
-- Not: SECURITY DEFINER fonksiyonlar (student_summaries, send_assignment,
-- handle_new_user...) RLS'i atlar; bunlar zaten çağıranın koç/müdür/öğrenci
-- ilişkisine göre süzer ve bu ilişkiler tek dershane içindedir.
--
-- Geri almak için: supabase/rollbacks/20261017120000_tenant_isolation.down.sql
-- =====================================================================

create policy "tenant isolation" on public.organizations as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant()))
  with check (tenant_id = (select public.my_tenant()));

-- Kullanıcı kendi profilini dershanesi boş olsa da görebilir.
create policy "tenant isolation" on public.profiles as restrictive
  for all to public
  using (id = (select auth.uid()) or tenant_id = (select public.my_tenant()))
  with check (id = (select auth.uid()) or tenant_id = (select public.my_tenant()));

do $$
declare
  t text;
begin
  foreach t in array array[
    'invite_codes', 'coach_students', 'parent_students', 'exams',
    'exam_subject_results', 'exam_wrong_topics', 'question_logs',
    'topic_progress', 'study_sessions', 'goals', 'tasks', 'coach_notes',
    'assignments', 'assignment_items', 'notifications'
  ] loop
    execute format(
      'create policy "tenant isolation" on public.%I as restrictive
         for all to public
         using (tenant_id = (select public.my_tenant())
                and (select public.my_tenant_active()))
         with check (tenant_id = (select public.my_tenant())
                     and (select public.my_tenant_active()))', t);
  end loop;
end;
$$;
