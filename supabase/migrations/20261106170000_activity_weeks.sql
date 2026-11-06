-- =====================================================================
-- Kokpit eğilim grafiği (NOTLAR §60)
-- ---------------------------------------------------------------------
-- activity_weeks(p_weeks): son N haftanın (7 günlük dilimler, en eskisi
-- önce; son dilim bugünle biter) aktif öğrenci, çözülen soru ve o tarihte
-- kayıtlı öğrenci sayısı. Müdür kurumunun, koç kendi öğrencilerinin
-- verisini görür (my_managed_students); öteki roller boş dizi alır.
-- "Aktif": o dilimde soru ya da çalışma kaydı var (kokpitteki "bu hafta
-- aktif" ile aynı tanım).
--
-- Geri almak için: supabase/rollbacks/20261106170000_activity_weeks.down.sql
-- =====================================================================

create or replace function public.activity_weeks(p_weeks int default 8)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  with n as (
    select least(greatest(coalesce(p_weeks, 8), 1), 26) as weeks
  ),
  st as (
    select p.id, p.created_at
      from public.my_managed_students() m(id)
      join public.profiles p on p.id = m.id and p.role = 'student'
  ),
  w as (
    select g as k,
           current_date - 7 * (g + 1) + 1 as d0,
           current_date - 7 * g as d1
      from n, generate_series(0, n.weeks - 1) g
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'start', w.d0,
           'end', w.d1,
           'students', (select count(*) from st where st.created_at::date <= w.d1),
           'active', (
             select count(*) from (
               select q.student_id
                 from public.question_logs q
                where q.student_id in (select id from st)
                  and q.logged_on between w.d0 and w.d1
               union
               select s.student_id
                 from public.study_sessions s
                where s.student_id in (select id from st)
                  and s.started_at >= w.d0 and s.started_at < w.d1 + 1
             ) x),
           'questions', (
             select coalesce(sum(q.correct + q.wrong + q.blank), 0)
               from public.question_logs q
              where q.student_id in (select id from st)
                and q.logged_on between w.d0 and w.d1))
         order by w.d0), '[]'::jsonb)
    from w
$$;
revoke all on function public.activity_weeks(int) from public, anon;
grant execute on function public.activity_weeks(int) to authenticated;
