-- =====================================================================
-- Optik okuma: cevap anahtarı, kazanımlar, soru soru cevaplar
-- ---------------------------------------------------------------------
--  * answer_keys: koçun / müdürün yüklediği deneme (ad, tür, yayınevi,
--    tarih, optik form şablonu). Kurum içindeki koç ve müdürler görür.
--    Optikten okunan denemeler bu anahtarın kimliğini batch_id olarak
--    taşır; böylece "Denemeler" ekranında tek paket görünür ve silinir.
--  * answer_key_items: ders + soru no → doğru cevap ve kazanım (isteğe
--    bağlı konu). Doğru cevabı boş soru iptal sayılır (değerlendirilmez).
--  * exam_answers: öğrencinin her soruda işaretlediği şık, doğru cevap ve
--    kazanım. Öğrenci kendi denemesinde "7. soru yanlış → kazanım" görür.
--  * submit_optic(): okunan optiği sunucuda değerlendirir (doğru / yanlış /
--    boş / net, yanlış konular) ve denemeyi yazar. Aynı öğrencinin optiği
--    yeniden okunursa deneme yerinde güncellenir (bildirim tekrar gitmez);
--    7 günlük düzeltme süresi geçmişse EXAM_LOCKED.
--  * Yazma yalnızca fonksiyonlarla; tenant_id istemciden alınmaz.
--
-- Geri almak için: supabase/rollbacks/20261030100000_optic_reading.down.sql
-- =====================================================================

alter table public.exams drop constraint exams_source_check;
alter table public.exams add constraint exams_source_check
  check (source in ('manual', 'import', 'optic'));

create table public.answer_keys (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.tenants (id),
  org_id      uuid not null references public.organizations (id) on delete cascade,
  created_by  uuid references public.profiles (id) on delete set null,
  name        text not null check (length(name) between 2 and 80),
  exam_type   public.exam_type not null,
  publisher   text check (publisher is null or length(publisher) <= 80),
  taken_on    date not null default current_date,
  -- Optik formun şablonu (uygulamada optic_template.dart, opticTemplates).
  template_id text not null check (template_id ~ '^[a-z0-9_]{1,40}$'),
  created_at  timestamptz not null default now()
);
create index on public.answer_keys (org_id, created_at desc);
create index on public.answer_keys (tenant_id);
create index on public.answer_keys (created_by);

create table public.answer_key_items (
  key_id      uuid not null references public.answer_keys (id) on delete cascade,
  subject_id  smallint not null references public.subjects (id),
  question_no smallint not null check (question_no between 1 and 80),
  correct     text check (correct in ('A', 'B', 'C', 'D', 'E')),
  outcome     text check (outcome is null or length(outcome) <= 300),
  topic_id    int references public.topics (id) on delete set null,
  primary key (key_id, subject_id, question_no)
);
create index on public.answer_key_items (subject_id);
create index on public.answer_key_items (topic_id);

create table public.exam_answers (
  exam_id     uuid not null references public.exams (id) on delete cascade,
  subject_id  smallint not null references public.subjects (id),
  question_no smallint not null check (question_no between 1 and 80),
  marked      text check (marked in ('A', 'B', 'C', 'D', 'E')),
  correct     text check (correct in ('A', 'B', 'C', 'D', 'E')),
  outcome     text,
  topic_id    int references public.topics (id) on delete set null,
  primary key (exam_id, subject_id, question_no)
);
create index on public.exam_answers (subject_id);
create index on public.exam_answers (topic_id);

alter table public.answer_keys      enable row level security;
alter table public.answer_key_items enable row level security;
alter table public.exam_answers     enable row level security;

-- Kurumdaki koç ve müdürler anahtarları görür.
create policy "org staff reads answer keys" on public.answer_keys
  for select to authenticated
  using ((select public.my_role()) in ('coach', 'admin')
         and org_id = (select public.my_org()));
create policy "tenant isolation" on public.answer_keys as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));
create policy "org staff reads answer key items" on public.answer_key_items
  for select to authenticated
  using (exists (select 1 from public.answer_keys k where k.id = key_id));
-- Denemeyi görebilen (öğrenci, velisi, koçu, müdürü) cevaplarını da görür.
create policy "view exam answers" on public.exam_answers
  for select to authenticated
  using (exists (select 1 from public.exams e where e.id = exam_id));

revoke all on public.answer_keys, public.answer_key_items, public.exam_answers from anon;
revoke insert, update, delete, truncate, trigger, references
  on public.answer_keys, public.answer_key_items, public.exam_answers from authenticated;
grant select on public.answer_keys, public.answer_key_items, public.exam_answers to authenticated;

-- Anahtarı kazanımlarıyla birlikte kaydeder; kimliğini döner.
-- p_items: [{"subject": "TYT_MAT", "no": 1, "correct": "C",
--            "outcome": "Trigonometri", "topic_id": 12}, ...]
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

  -- Ders bu sınav türünde olmalı ve soru no ders soru sayısını aşmamalı.
  select count(*) into v_bad
  from jsonb_array_elements(p_items) i
  left join public.subjects s on s.code = i->>'subject' and s.exam_type = p_exam_type
  where s.id is null
     or (i->>'no')::int not between 1 and s.question_count;
  if v_bad > 0 then
    raise exception 'INVALID_ITEMS';
  end if;

  insert into public.answer_keys
    (tenant_id, org_id, created_by, name, exam_type, publisher, taken_on, template_id)
  values (public.my_tenant(), public.my_org(), auth.uid(), trim(p_name),
          p_exam_type, nullif(trim(p_publisher), ''),
          coalesce(p_taken_on, current_date), p_template)
  returning id into v_id;

  insert into public.answer_key_items (key_id, subject_id, question_no, correct, outcome, topic_id)
  select v_id, s.id, (i->>'no')::smallint,
         nullif(upper(trim(i->>'correct')), ''),
         left(nullif(trim(i->>'outcome'), ''), 300),
         t.id
  from jsonb_array_elements(p_items) i
  join public.subjects s on s.code = i->>'subject'
  -- Konu yalnızca aynı derse aitse bağlanır.
  left join public.topics t on t.id = (i->>'topic_id')::int and t.subject_id = s.id
  on conflict (key_id, subject_id, question_no) do update
    set correct = excluded.correct, outcome = excluded.outcome, topic_id = excluded.topic_id;

  return v_id;
end;
$$;
revoke execute on function public.create_answer_key(text, public.exam_type, text, date, text, jsonb)
  from public, anon;
grant execute on function public.create_answer_key(text, public.exam_type, text, date, text, jsonb)
  to authenticated;

-- Anahtarı siler. Okunmuş optikler (denemeler) kalır; silmek için
-- "Denemeler" ekranındaki paket silme (7 gün) kullanılır.
create or replace function public.delete_answer_key(p_key uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  delete from public.answer_keys
  where id = p_key and created_by = auth.uid() and tenant_id = public.my_tenant();
  if not found then
    raise exception 'KEY_NOT_FOUND';
  end if;
end;
$$;
revoke execute on function public.delete_answer_key(uuid) from public, anon;
grant execute on function public.delete_answer_key(uuid) to authenticated;

-- Okunan optiği değerlendirip öğrencinin denemesi olarak yazar.
-- p_answers: {"TYT_MAT": ["A", null, "C", ...], ...}; dizideki i. eleman
-- dersin i+1. sorusu, null boş. Dönüş: {exam_id, updated, correct, wrong,
-- blank, net}.
create or replace function public.submit_optic(p_key uuid, p_student uuid, p_answers jsonb)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_key     public.answer_keys%rowtype;
  v_student public.profiles%rowtype;
  v_exam    uuid;
  v_created timestamptz;
  v_updated boolean := false;
  v_field   public.field_type;
  v_sum     record;
begin
  if public.my_role() not in ('coach', 'admin') or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
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

  -- Okunan cevaplar (yalnızca anahtardaki sorular).
  drop table if exists _marks;
  create temp table _marks on commit drop as
    select k.subject_id, k.question_no, k.correct, k.outcome, k.topic_id,
           case when upper(p_answers -> s.code ->> (k.question_no - 1))
                     in ('A', 'B', 'C', 'D', 'E')
                then upper(p_answers -> s.code ->> (k.question_no - 1)) end as marked,
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
        publisher = v_key.publisher, taken_on = v_key.taken_on
    where id = v_exam;
    v_updated := true;
  else
    insert into public.exams
      (student_id, exam_type, field, name, publisher, taken_on, created_by, source, batch_id)
    values (p_student, v_key.exam_type, v_field, v_key.name, v_key.publisher,
            v_key.taken_on, auth.uid(), 'optic', p_key)
    returning id into v_exam;
  end if;

  -- TYT'de tüm dersler, AYT/YDT'de yalnızca işaret konan dersler sayılır.
  insert into public.exam_answers
    (exam_id, subject_id, question_no, marked, correct, outcome, topic_id)
  select v_exam, m.subject_id, m.question_no, m.marked, m.correct, m.outcome, m.topic_id
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
revoke execute on function public.submit_optic(uuid, uuid, jsonb) from public, anon;
grant execute on function public.submit_optic(uuid, uuid, jsonb) to authenticated;
