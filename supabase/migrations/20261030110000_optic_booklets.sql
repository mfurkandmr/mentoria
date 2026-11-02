-- =====================================================================
-- Optik okuma: kitapçık türü (A / B)
-- ---------------------------------------------------------------------
-- Denemelerde B kitapçığı aynı soruları farklı sırayla verir. Kazanım
-- tablosundaki "B Soru No" sütunu her sorunun B kitapçığındaki yerini
-- söyler; doğru cevap ve kazanım aynı sorunun kendisidir.
--  * answer_key_items.question_no_b: sorunun B kitapçığındaki numarası
--    (ders içi). Boşsa anahtarın B kitapçığı yoktur.
--  * submit_optic(..., p_booklet): B kitapçığında öğrencinin i. işareti,
--    question_no_b = i olan soruya yazılır. Kayıtlar hep A numarasıyla
--    tutulur (sınıf karşılaştırması, Excel); exam_answers.booklet_no
--    öğrencinin kendi kitapçığındaki numarası (öğrenciye bu gösterilir).
--  * exams.booklet: öğrencinin kitapçık türü (optikten okunan).
--
-- Geri almak için: supabase/rollbacks/20261030110000_optic_booklets.down.sql
-- =====================================================================

alter table public.answer_key_items
  add column question_no_b smallint check (question_no_b between 1 and 80);
alter table public.exam_answers add column booklet_no smallint;
alter table public.exams
  add column booklet text check (booklet in ('A', 'B'));

-- Kazanımlarla birlikte anahtar; p_items'ta isteğe bağlı "no_b".
create or replace function public.create_answer_key(
  p_name text, p_exam_type public.exam_type, p_publisher text,
  p_taken_on date, p_template text, p_items jsonb)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_id  uuid;
  v_bad int;
begin
  if public.my_role() not in ('coach', 'admin') or public.my_org() is null
     or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'NO_ITEMS';
  end if;

  -- Ders bu sınav türünde olmalı, A ve B numaraları ders soru sayısını
  -- aşmamalı, bir B numarası aynı derste iki soruya verilmemeli.
  select count(*) into v_bad
  from jsonb_array_elements(p_items) i
  left join public.subjects s on s.code = i->>'subject' and s.exam_type = p_exam_type
  where s.id is null
     or (i->>'no')::int not between 1 and s.question_count
     or (i->>'no_b' is not null
         and (i->>'no_b')::int not between 1 and s.question_count);
  if v_bad = 0 then
    select count(*) into v_bad
    from (select i->>'subject', i->>'no_b'
          from jsonb_array_elements(p_items) i
          where i->>'no_b' is not null
          group by 1, 2 having count(*) > 1) d;
  end if;
  if v_bad > 0 then
    raise exception 'INVALID_ITEMS';
  end if;

  insert into public.answer_keys
    (tenant_id, org_id, created_by, name, exam_type, publisher, taken_on, template_id)
  values (public.my_tenant(), public.my_org(), auth.uid(), trim(p_name),
          p_exam_type, nullif(trim(p_publisher), ''),
          coalesce(p_taken_on, current_date), p_template)
  returning id into v_id;

  insert into public.answer_key_items
    (key_id, subject_id, question_no, question_no_b, correct, outcome, topic_id)
  select v_id, s.id, (i->>'no')::smallint, (i->>'no_b')::smallint,
         nullif(upper(trim(i->>'correct')), ''),
         left(nullif(trim(i->>'outcome'), ''), 300),
         t.id
  from jsonb_array_elements(p_items) i
  join public.subjects s on s.code = i->>'subject'
  left join public.topics t on t.id = (i->>'topic_id')::int and t.subject_id = s.id
  on conflict (key_id, subject_id, question_no) do update
    set question_no_b = excluded.question_no_b, correct = excluded.correct,
        outcome = excluded.outcome, topic_id = excluded.topic_id;

  return v_id;
end;
$$;

drop function public.submit_optic(uuid, uuid, jsonb);

-- Okunan optiği değerlendirip öğrencinin denemesi olarak yazar.
-- p_answers: {"TYT_MAT": ["A", null, "C", ...], ...}; dizideki i. eleman
-- öğrencinin kitapçığında dersin i+1. sorusu. B kitapçığında anahtarın B
-- numaraları yoksa NO_B_KEY.
create or replace function public.submit_optic(
  p_key uuid, p_student uuid, p_answers jsonb, p_booklet text default 'A')
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_key     public.answer_keys%rowtype;
  v_student public.profiles%rowtype;
  v_b       boolean := upper(coalesce(p_booklet, 'A')) = 'B';
  v_exam    uuid;
  v_created timestamptz;
  v_updated boolean := false;
  v_field   public.field_type;
  v_sum     record;
begin
  if public.my_role() not in ('coach', 'admin') or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  if upper(coalesce(p_booklet, 'A')) not in ('A', 'B') then
    raise exception 'INVALID_BOOKLET';
  end if;
  select * into v_key from public.answer_keys
  where id = p_key and org_id = public.my_org() and tenant_id = public.my_tenant();
  if not found then
    raise exception 'KEY_NOT_FOUND';
  end if;
  select * into v_student from public.profiles where id = p_student and role = 'student';
  if not found or not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  if jsonb_typeof(p_answers) <> 'object' then
    raise exception 'INVALID_ANSWERS';
  end if;
  if v_b and exists (select 1 from public.answer_key_items
                     where key_id = p_key and correct is not null
                       and question_no_b is null) then
    raise exception 'NO_B_KEY';
  end if;

  -- Okunan cevaplar (yalnızca anahtardaki sorular), A numarasıyla.
  drop table if exists _marks;
  create temp table _marks on commit drop as
    select k.subject_id, k.question_no, k.correct, k.outcome, k.topic_id,
           case when v_b then k.question_no_b end as booklet_no,
           case when upper(p_answers -> s.code ->>
                       ((case when v_b then k.question_no_b else k.question_no end) - 1))
                     in ('A', 'B', 'C', 'D', 'E')
                then upper(p_answers -> s.code ->>
                       ((case when v_b then k.question_no_b else k.question_no end) - 1))
           end as marked,
           -- Öğrenci bu dersin optiğine en az bir işaret koydu mu (AYT'de
           -- alanı dışındaki testler boş kalır).
           exists (select 1 from jsonb_array_elements_text(
                     coalesce(p_answers -> s.code, '[]'::jsonb)) m
                   where upper(m) in ('A', 'B', 'C', 'D', 'E')) as touched
    from public.answer_key_items k
    join public.subjects s on s.id = k.subject_id
    where k.key_id = p_key;

  -- AYT'de alan: profildeki alan, yoksa okunan derslerden tahmin.
  if v_key.exam_type = 'AYT' then
    v_field := coalesce(v_student.field, (
      select case
        when bool_or(s.code in ('AYT_FIZ', 'AYT_KIM', 'AYT_BIY')) then 'SAY'
        when bool_or(s.code in ('AYT_TAR2', 'AYT_COG2', 'AYT_FELG', 'AYT_DIN')) then 'SOZ'
        when bool_or(s.code = 'AYT_MAT') then 'EA'
        else 'SOZ' end::public.field_type
      from _marks m join public.subjects s on s.id = m.subject_id
      where m.touched));
  elsif v_key.exam_type = 'YDT' then
    v_field := 'DIL';
  end if;

  select e.id, e.created_at into v_exam, v_created
  from public.exams e
  where e.batch_id = p_key and e.student_id = p_student;

  if v_exam is not null then
    if not public.exam_editable(v_created) then
      raise exception 'EXAM_LOCKED';
    end if;
    delete from public.exam_subject_results where exam_id = v_exam;
    delete from public.exam_wrong_topics where exam_id = v_exam;
    delete from public.exam_answers where exam_id = v_exam;
    update public.exams
    set name = v_key.name, exam_type = v_key.exam_type, field = v_field,
        publisher = v_key.publisher, taken_on = v_key.taken_on,
        booklet = case when v_b then 'B' else 'A' end
    where id = v_exam;
    v_updated := true;
  else
    insert into public.exams
      (student_id, exam_type, field, name, publisher, taken_on, created_by,
       source, batch_id, booklet)
    values (p_student, v_key.exam_type, v_field, v_key.name, v_key.publisher,
            v_key.taken_on, auth.uid(), 'optic', p_key,
            case when v_b then 'B' else 'A' end)
    returning id into v_exam;
  end if;

  -- TYT'de tüm dersler, AYT/YDT'de yalnızca işaret konan dersler sayılır.
  insert into public.exam_answers
    (exam_id, subject_id, question_no, booklet_no, marked, correct, outcome, topic_id)
  select v_exam, m.subject_id, m.question_no, m.booklet_no, m.marked, m.correct,
         m.outcome, m.topic_id
  from _marks m
  where v_key.exam_type = 'TYT' or m.touched;

  -- İptal sorular (doğru cevabı boş) değerlendirilmez.
  insert into public.exam_subject_results (exam_id, subject_id, correct, wrong, blank)
  select v_exam, a.subject_id,
         count(*) filter (where a.marked = a.correct),
         count(*) filter (where a.marked is not null and a.marked <> a.correct),
         count(*) filter (where a.marked is null)
  from public.exam_answers a
  where a.exam_id = v_exam and a.correct is not null
  group by a.subject_id;

  insert into public.exam_wrong_topics (exam_id, topic_id, count)
  select v_exam, a.topic_id, count(*)
  from public.exam_answers a
  where a.exam_id = v_exam and a.topic_id is not null and a.correct is not null
    and (a.marked is null or a.marked <> a.correct)
  group by a.topic_id;

  select coalesce(sum(r.correct), 0)::int as c, coalesce(sum(r.wrong), 0)::int as w,
         coalesce(sum(r.blank), 0)::int as b, coalesce(sum(r.net), 0) as n
  into v_sum
  from public.exam_subject_results r where r.exam_id = v_exam;

  return jsonb_build_object('exam_id', v_exam, 'updated', v_updated,
    'correct', v_sum.c, 'wrong', v_sum.w, 'blank', v_sum.b, 'net', v_sum.n);
end;
$$;
revoke execute on function public.submit_optic(uuid, uuid, jsonb, text) from public, anon;
grant execute on function public.submit_optic(uuid, uuid, jsonb, text) to authenticated;
