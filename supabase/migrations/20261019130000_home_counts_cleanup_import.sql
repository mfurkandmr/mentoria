-- Zamanla büyüyen yükleri kes:
--   1. Ana sayfa kısayolları (Odak Bahçesi çiçek sayısı, Hata Defteri tekrar
--      sayısı) için öğrencinin tüm oturumları ve tüm hata kartları
--      indiriliyordu. Artık yalnızca sayılar: student_shortcut_counts(), ayrıca
--      student_home() paketinde 'shortcuts'.
--   2. Bildirimler hiç silinmiyordu (Günün Sorusu her gün her öğrenciye bir
--      satır). 90 günden eskiler gece silinir; duyurular hariç.
--   3. Toplu deneme yüklemesi öğrenci başına 2-3 istek atıyordu. Artık
--      import_exam_batch() tek istekte (uygulama 200'lük parçalar yollar).
-- Geri almak için: supabase/rollbacks/20261019130000_home_counts_cleanup_import.down.sql

-- 1. Kısayol sayıları -----------------------------------------------------------
-- SECURITY INVOKER: RLS aynen geçerli (başkasının öğrencisi için 0 döner).
-- Çiçek kuralı garden.dart FlowerSize.of ile aynı: 20 dakikadan kısa pomodoro
-- solmuş sayılır. Tekrar kuralı MistakeCard.isDue ile aynı: ustalaşılmamış ve
-- tekrar günü bugün ya da önce (p_today: öğrencinin kendi günü).
create or replace function public.student_shortcut_counts(
  p_student uuid,
  p_today date default current_date
) returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'flowers', (
      select count(*)::int from public.study_sessions s
      where s.student_id = p_student
        and not (s.type = 'pomodoro' and s.duration_sec < 1200)),
    'mistakes_total', (
      select count(*)::int from public.mistake_cards m
      where m.student_id = p_student),
    'mistakes_due', (
      select count(*)::int from public.mistake_cards m
      where m.student_id = p_student
        and m.mastered_at is null
        and m.due_on <= p_today)
  );
$$;
revoke all on function public.student_shortcut_counts(uuid, date) from public, anon;
grant execute on function public.student_shortcut_counts(uuid, date) to authenticated;

-- student_home'a p_today ve 'shortcuts' eklenir (eski 3 parametreli sürüm
-- yalnızca bugün yayımlanan uygulamada vardı, kaldırılıyor).
drop function if exists public.student_home(uuid, date, timestamptz);

create or replace function public.student_home(
  p_student uuid,
  p_since date,
  p_since_ts timestamptz,
  p_today date default current_date
) returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'logs', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', l.id,
          'correct', l.correct,
          'wrong', l.wrong,
          'blank', l.blank,
          'logged_on', l.logged_on,
          'source', l.source,
          'topic_id', l.topic_id,
          'subjects', jsonb_build_object('code', s.code),
          'topics', case when t.id is null then null
                         else jsonb_build_object('name', t.name) end
        ) order by l.logged_on desc, l.created_at desc)
      from question_logs l
      join subjects s on s.id = l.subject_id
      left join topics t on t.id = l.topic_id
      where l.student_id = p_student and l.logged_on >= p_since
    ), '[]'::jsonb),

    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', ss.id,
          'type', ss.type,
          'started_at', ss.started_at,
          'duration_sec', ss.duration_sec,
          'subjects', case when s.id is null then null
                           else jsonb_build_object('code', s.code) end
        ) order by ss.started_at desc)
      from study_sessions ss
      left join subjects s on s.id = ss.subject_id
      where ss.student_id = p_student and ss.started_at >= p_since_ts
    ), '[]'::jsonb),

    'goals', (select to_jsonb(g) from goals g where g.student_id = p_student),

    'topic_progress', coalesce((
      select jsonb_agg(jsonb_build_object(
          'topic_id', tp.topic_id, 'status', tp.status))
      from topic_progress tp
      where tp.student_id = p_student
    ), '[]'::jsonb),

    'exams', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', e.id,
          'exam_type', e.exam_type,
          'field', e.field,
          'name', e.name,
          'publisher', e.publisher,
          'taken_on', e.taken_on,
          'created_at', e.created_at,
          'exam_subject_results', coalesce((
            select jsonb_agg(jsonb_build_object(
                'correct', r.correct,
                'wrong', r.wrong,
                'blank', r.blank,
                'subjects', jsonb_build_object('code', s.code)))
            from exam_subject_results r
            join subjects s on s.id = r.subject_id
            where r.exam_id = e.id
          ), '[]'::jsonb)
        ) order by e.taken_on desc, e.created_at desc)
      from exams e
      where e.student_id = p_student
    ), '[]'::jsonb),

    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', a.id,
          'title', a.title,
          'note', a.note,
          'due_on', a.due_on,
          'created_at', a.created_at,
          'coach', case when c.id is null then null
                        else jsonb_build_object('full_name', c.full_name) end,
          'assignment_items', coalesce((
            select jsonb_agg(jsonb_build_object(
                'id', i.id,
                'question_count', i.question_count,
                'note', i.note,
                'sort', i.sort,
                'done', i.done,
                'subjects', jsonb_build_object('code', s.code),
                'topics', case when t.id is null then null
                               else jsonb_build_object('id', t.id, 'name', t.name) end))
            from assignment_items i
            join subjects s on s.id = i.subject_id
            left join topics t on t.id = i.topic_id
            where i.assignment_id = a.id
          ), '[]'::jsonb)
        ) order by a.created_at desc)
      from assignments a
      left join profiles c on c.id = a.coach_id
      where a.student_id = p_student
    ), '[]'::jsonb),

    'shortcuts', public.student_shortcut_counts(p_student, p_today)
  );
$$;

revoke all on function public.student_home(uuid, date, timestamptz, date) from public, anon;
grant execute on function public.student_home(uuid, date, timestamptz, date) to authenticated;

-- 2. Eski bildirimleri temizle ---------------------------------------------------
-- Uygulama son 50 bildirimi gösteriyor; 90 günden eskiler gereksiz. Duyurular
-- my_announcements() bildirim satırlarından okunduğu için tutulur.
create or replace function public.cleanup_old_notifications(p_days int default 90)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_n int;
begin
  delete from public.notifications
  where created_at < now() - make_interval(days => greatest(p_days, 30))
    and kind <> 'announcement';
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.cleanup_old_notifications(int) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    -- 03.30 Türkiye saati.
    perform cron.schedule('cleanup-notifications', '30 0 * * *',
      'select public.cleanup_old_notifications()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); temizlik zamanlanmadı';
  end if;
end;
$$;

-- 3. Toplu deneme yükleme --------------------------------------------------------
-- SECURITY INVOKER: koç/müdür yalnızca kendi öğrencilerine deneme ekleyebilir
-- (mevcut RLS). Öğrenci başına ayrı alt işlem: biri hata verirse (yetki,
-- geçersiz ders kodu) diğerleri kaydedilir; hatalılar 'failed' listesinde döner.
--   p_exam: {"exam_type","field","name","publisher","taken_on"}
--   p_rows: [{"student_id", "results": [{"code","correct","wrong","blank"}]}]
create or replace function public.import_exam_batch(
  p_batch uuid,
  p_exam jsonb,
  p_rows jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_row     jsonb;
  v_student uuid;
  v_exam    uuid;
  v_saved   int := 0;
  v_failed  jsonb := '[]'::jsonb;
  v_n       int;
begin
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 500 then
    raise exception 'IMPORT_TOO_LARGE';
  end if;

  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_student := (v_row->>'student_id')::uuid;
    begin
      insert into public.exams
        (student_id, exam_type, field, name, publisher, taken_on, source, batch_id)
      values (
        v_student,
        (p_exam->>'exam_type')::public.exam_type,
        nullif(p_exam->>'field', '')::public.field_type,
        p_exam->>'name',
        nullif(p_exam->>'publisher', ''),
        (p_exam->>'taken_on')::date,
        'import',
        p_batch)
      returning id into v_exam;

      insert into public.exam_subject_results (exam_id, subject_id, correct, wrong, blank)
      select v_exam, s.id, (r->>'correct')::int, (r->>'wrong')::int, (r->>'blank')::int
      from jsonb_array_elements(v_row->'results') r
      join public.subjects s on s.code = r->>'code';

      -- Bilinmeyen ders kodu ya da boş sonuç: bu öğrenciyi kaydetme.
      get diagnostics v_n = row_count;
      if v_n = 0 or v_n <> jsonb_array_length(v_row->'results') then
        raise exception 'BAD_RESULTS';
      end if;
      v_saved := v_saved + 1;
    exception when others then
      v_failed := v_failed || to_jsonb(v_student);
    end;
  end loop;

  return jsonb_build_object('saved', v_saved, 'failed', v_failed);
end;
$$;
revoke all on function public.import_exam_batch(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.import_exam_batch(uuid, jsonb, jsonb) to authenticated;
