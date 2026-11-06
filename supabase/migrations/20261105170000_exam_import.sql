-- =====================================================================
-- Kurum sınavı: optik okuyucu Excel'i içe aktarma ve kazanım analizi
-- ---------------------------------------------------------------------
-- Mevcut optik okuma yapısı (20261030100000/110000) genişletilir; ikinci
-- bir "sınav" yapısı kurulmaz:
--  * answer_keys = kurumun sınavı. Yeni: tür (deneme / konu tarama),
--    durum (taslak / yayında), yanlış doğruyu götürür mü + katsayı.
--  * answer_key_subjects: sınavın dersleri (soru sayısı, sıra, katsayı).
--  * answer_key_items = A kitapçığı: soru → doğru cevap, kazanım, zorluk,
--    iptal. answer_key_booklets: B / C / D kitapçığında soru → A'daki soru
--    (sıra karışıksa) ve o kitapçığın doğru cevabı (şık karışıksa).
--  * learning_outcomes: kurumun kazanım havuzu (ders > konu > alt konu,
--    MEB kodu); isteğe bağlı olarak müfredat konusuna (topics) bağlanır.
--  * exam_sheets: öğrencinin ham optiği (kitapçık sırasıyla cevaplar).
--    Taslak sınavda yalnızca burada durur; öğrenci, veli ve istatistikler
--    görmez. Yayınlanınca (ve yayındaki sınava her yeni yüklemede) sunucu
--    puanlayıp exams / exam_subject_results / exam_answers'a yazar. Anahtar
--    sonradan değişirse (iptal soru, düzeltilen cevap) hepsi yeniden
--    puanlanır.
--  * exams: ağırlıklı toplam net, kurum ve sınıf sıralaması, sınıf
--    (sınav anındaki). exam_subject_results: yanlış katsayısı (net artık
--    doğru − yanlış × katsayı; elle girilen denemede 0,25), ders katsayısı,
--    ders sıralamaları. Bu sütunları yalnızca puanlama yazar.
--  * exam_imports (yükleme kaydı), import_templates (sütun eşleştirme).
--  * Görünümler (okuyanın yetkisiyle): v_student_outcome_analysis,
--    v_class_outcome_analysis, v_institution_outcome_analysis,
--    v_question_difficulty. Koçun kurum geneli için exam_report().
--
-- Geri almak için: supabase/rollbacks/20261105170000_exam_import.down.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- Kazanım havuzu
-- ---------------------------------------------------------------------
create table public.learning_outcomes (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  subject_id smallint not null references public.subjects (id),
  parent_id  uuid references public.learning_outcomes (id) on delete cascade,
  name       text not null check (length(trim(name)) between 1 and 200),
  code       text check (code is null or length(code) <= 40),
  topic_id   int references public.topics (id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index learning_outcomes_unique on public.learning_outcomes
  (org_id, subject_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
   public.norm_key(name));
create index on public.learning_outcomes (parent_id);
create index on public.learning_outcomes (topic_id);
create index on public.learning_outcomes (tenant_id);

-- "Konu — Alt konu" (kökten yaprağa).
create or replace function public.outcome_label(p_id uuid)
returns text
language sql stable security definer set search_path = ''
as $$
  with recursive up as (
    select id, parent_id, name, 0 as depth from public.learning_outcomes where id = p_id
    union all
    select o.id, o.parent_id, o.name, up.depth + 1
    from public.learning_outcomes o join up on o.id = up.parent_id
    where up.depth < 10
  )
  select string_agg(name, ' — ' order by depth desc) from up
$$;
revoke all on function public.outcome_label(uuid) from public, anon;
grant execute on function public.outcome_label(uuid) to authenticated;

-- Kazanımın ya da en yakın üstünün müfredat konusu.
create or replace function public.outcome_topic(p_id uuid)
returns int
language sql stable security definer set search_path = ''
as $$
  with recursive up as (
    select id, parent_id, topic_id, 0 as depth from public.learning_outcomes where id = p_id
    union all
    select o.id, o.parent_id, o.topic_id, up.depth + 1
    from public.learning_outcomes o join up on o.id = up.parent_id
    where up.depth < 10
  )
  select topic_id from up where topic_id is not null order by depth limit 1
$$;
revoke all on function public.outcome_topic(uuid) from public, anon;
grant execute on function public.outcome_topic(uuid) to authenticated;

create or replace function public.guard_learning_outcome()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.org_id := old.org_id;
    new.tenant_id := old.tenant_id;
    new.subject_id := old.subject_id;
    new.created_at := old.created_at;
  elsif auth.uid() is not null then
    new.org_id := public.my_org();
    new.created_at := now();
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);
  new.name := trim(new.name);
  new.code := nullif(trim(new.code), '');
  if new.parent_id is not null and not exists (
       select 1 from public.learning_outcomes p
       where p.id = new.parent_id and p.org_id = new.org_id
         and p.subject_id = new.subject_id and p.id <> new.id) then
    raise exception 'INVALID_PARENT';
  end if;
  if new.topic_id is not null and not exists (
       select 1 from public.topics t
       where t.id = new.topic_id and t.subject_id = new.subject_id) then
    new.topic_id := null;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_learning_outcome() from public, anon, authenticated;
create trigger guard_learning_outcome before insert or update on public.learning_outcomes
  for each row execute function public.guard_learning_outcome();

-- ---------------------------------------------------------------------
-- Sınav (answer_keys) genişletmesi
-- ---------------------------------------------------------------------
alter table public.answer_keys
  add column kind text not null default 'deneme'
    check (kind in ('deneme', 'konu_tarama')),
  -- Mevcut (kamerayla okunan) anahtarlar yayında sayılır.
  add column status text not null default 'published'
    check (status in ('draft', 'published')),
  add column wrong_penalty boolean not null default true,
  add column penalty_ratio numeric(5, 4) not null default 0.25
    check (penalty_ratio between 0 and 1),
  add column published_at timestamptz;
alter table public.answer_keys alter column template_id set default 'standart_yks';

create table public.answer_key_subjects (
  key_id         uuid not null references public.answer_keys (id) on delete cascade,
  subject_id     smallint not null references public.subjects (id),
  question_count smallint not null check (question_count between 1 and 80),
  sort           smallint not null default 0,
  weight         numeric(5, 3) not null default 1 check (weight > 0 and weight <= 10),
  primary key (key_id, subject_id)
);

create table public.answer_key_classrooms (
  key_id       uuid not null references public.answer_keys (id) on delete cascade,
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  primary key (key_id, classroom_id)
);
create index on public.answer_key_classrooms (classroom_id);

alter table public.answer_key_items
  add column outcome_id uuid references public.learning_outcomes (id) on delete set null,
  add column difficulty text check (difficulty in ('easy', 'medium', 'hard')),
  add column cancelled boolean not null default false;
create index on public.answer_key_items (outcome_id);

create table public.answer_key_booklets (
  key_id      uuid not null references public.answer_keys (id) on delete cascade,
  subject_id  smallint not null references public.subjects (id),
  booklet     text not null check (booklet in ('B', 'C', 'D')),
  -- Sorunun bu kitapçıktaki numarası.
  question_no smallint not null check (question_no between 1 and 80),
  -- Aynı sorunun A kitapçığındaki numarası.
  item_no     smallint not null check (item_no between 1 and 80),
  -- Bu kitapçıktaki doğru şık; boşsa A'daki cevap (yalnızca sıra karışık).
  correct     text check (correct in ('A', 'B', 'C', 'D', 'E')),
  primary key (key_id, subject_id, booklet, question_no),
  unique (key_id, subject_id, booklet, item_no)
);

-- Mevcut anahtarlar: dersler (müfredat soru sayısıyla) ve B kitapçığı.
insert into public.answer_key_subjects (key_id, subject_id, question_count, sort)
select distinct i.key_id, i.subject_id, s.question_count, s.sort
from public.answer_key_items i join public.subjects s on s.id = i.subject_id;
insert into public.answer_key_booklets (key_id, subject_id, booklet, question_no, item_no)
select key_id, subject_id, 'B', question_no_b, question_no
from public.answer_key_items where question_no_b is not null;

-- ---------------------------------------------------------------------
-- Sonuç sütunları
-- ---------------------------------------------------------------------
alter table public.exams drop constraint if exists exams_booklet_check;
alter table public.exams add constraint exams_booklet_check
  check (booklet in ('A', 'B', 'C', 'D'));
alter table public.exams
  add column total_net    numeric(7, 2),
  add column rank_org     int,
  add column rank_class   int,
  add column classroom_id uuid references public.classrooms (id) on delete set null;
create index on public.exams (classroom_id);

alter table public.exam_subject_results
  add column wrong_penalty numeric(5, 4) not null default 0.25
    check (wrong_penalty between 0 and 1),
  add column weight     numeric(5, 3) not null default 1,
  add column rank_org   int,
  add column rank_class int;
alter table public.exam_subject_results drop column net;
alter table public.exam_subject_results
  add column net numeric(6, 2) generated always as (correct - wrong * wrong_penalty) stored;

alter table public.exam_answers
  add column outcome_id uuid references public.learning_outcomes (id) on delete set null;
create index on public.exam_answers (outcome_id);
create index on public.exam_answers (subject_id, question_no);

-- Puanlama sütunlarını yalnızca puanlama fonksiyonları yazar
-- (mentoria.scoring = on). Elle girilen denemede yanlış katsayısı 0,25.
create or replace function public.guard_exam_scoring()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if coalesce(current_setting('mentoria.scoring', true), '') = 'on' then
    return new;
  end if;
  if tg_table_name = 'exams' then
    if tg_op = 'INSERT' then
      new.total_net := null; new.rank_org := null;
      new.rank_class := null; new.classroom_id := null;
    else
      new.total_net := old.total_net; new.rank_org := old.rank_org;
      new.rank_class := old.rank_class; new.classroom_id := old.classroom_id;
    end if;
  else
    if tg_op = 'INSERT' then
      new.wrong_penalty := 0.25; new.weight := 1;
      new.rank_org := null; new.rank_class := null;
    else
      new.wrong_penalty := old.wrong_penalty; new.weight := old.weight;
      new.rank_org := old.rank_org; new.rank_class := old.rank_class;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_exam_scoring() from public, anon, authenticated;
create trigger guard_exam_scoring before insert or update on public.exams
  for each row execute function public.guard_exam_scoring();
create trigger guard_exam_scoring before insert or update on public.exam_subject_results
  for each row execute function public.guard_exam_scoring();

-- ---------------------------------------------------------------------
-- Ham optikler, yüklemeler, şablonlar
-- ---------------------------------------------------------------------
create table public.exam_imports (
  id          uuid primary key default gen_random_uuid(),
  key_id      uuid not null references public.answer_keys (id) on delete cascade,
  org_id      uuid not null references public.organizations (id) on delete cascade,
  tenant_id   uuid not null references public.tenants (id),
  file_name   text check (file_name is null or length(file_name) <= 200),
  created_by  uuid references public.profiles (id) on delete set null,
  row_count   int not null default 0,
  matched     int not null default 0,
  unmatched   int not null default 0,
  failed      int not null default 0,
  saved       int not null default 0,
  status      text not null default 'running' check (status in ('running', 'done')),
  log         jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index on public.exam_imports (key_id);
create index on public.exam_imports (org_id);
create index on public.exam_imports (tenant_id);
create index on public.exam_imports (created_by);

create table public.exam_sheets (
  key_id     uuid not null references public.answer_keys (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  booklet    text not null default 'A' check (booklet in ('A', 'B', 'C', 'D')),
  -- {"TYT_MAT": ["A", null, ...]}: öğrencinin kendi kitapçığındaki sırayla.
  answers    jsonb not null check (jsonb_typeof(answers) = 'object'),
  source     text not null default 'import' check (source in ('optic', 'import')),
  import_id  uuid references public.exam_imports (id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (key_id, student_id)
);
create index on public.exam_sheets (student_id);
create index on public.exam_sheets (org_id);
create index on public.exam_sheets (tenant_id);
create index on public.exam_sheets (import_id);

create table public.import_templates (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  tenant_id  uuid not null references public.tenants (id),
  name       text not null check (length(trim(name)) between 1 and 60),
  -- {"student_no": "ogrenci_no", "name": "...", "class": "...",
  --  "booklet": "...", "columns": [{"column": "FEN", "subjects": [...]}]}
  mapping    jsonb not null check (jsonb_typeof(mapping) = 'object'),
  created_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);
create unique index import_templates_unique on public.import_templates
  (org_id, public.norm_key(name));
create index on public.import_templates (tenant_id);
create index on public.import_templates (created_by);

create or replace function public.guard_import_template()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.org_id := old.org_id;
    new.created_by := old.created_by;
  elsif auth.uid() is not null then
    new.org_id := public.my_org();
    new.created_by := auth.uid();
  end if;
  new.tenant_id := (select tenant_id from public.organizations where id = new.org_id);
  new.name := trim(new.name);
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function public.guard_import_template() from public, anon, authenticated;
create trigger guard_import_template before insert or update on public.import_templates
  for each row execute function public.guard_import_template();

-- Mevcut kamerayla okunan optikler: ham kayıt, toplam net.
insert into public.exam_sheets
  (key_id, student_id, org_id, tenant_id, booklet, answers, source, updated_at)
select e.batch_id, e.student_id, k.org_id, k.tenant_id, coalesce(e.booklet, 'A'),
       coalesce((
         select jsonb_object_agg(s.code, (
                  select jsonb_agg(a2.marked order by g)
                  from generate_series(1, m.mx) g
                  left join public.exam_answers a2
                    on a2.exam_id = e.id and a2.subject_id = m.subject_id
                   and coalesce(a2.booklet_no, a2.question_no) = g))
         from (select subject_id, max(coalesce(booklet_no, question_no)) mx
               from public.exam_answers where exam_id = e.id group by subject_id) m
         join public.subjects s on s.id = m.subject_id), '{}'::jsonb),
       'optic', e.created_at
from public.exams e
join public.answer_keys k on k.id = e.batch_id
where e.source = 'optic'
on conflict do nothing;

-- ---------------------------------------------------------------------
-- Yetki: kurum personeli
-- ---------------------------------------------------------------------
create or replace function public.is_org_staff(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null and p_org is not null
     and public.my_role() in ('coach', 'admin')
     and public.my_org() = p_org and public.my_tenant_active()
$$;
revoke all on function public.is_org_staff(uuid) from public, anon;
grant execute on function public.is_org_staff(uuid) to authenticated;

alter table public.learning_outcomes     enable row level security;
alter table public.answer_key_subjects   enable row level security;
alter table public.answer_key_classrooms enable row level security;
alter table public.answer_key_booklets   enable row level security;
alter table public.exam_imports          enable row level security;
alter table public.exam_sheets           enable row level security;
alter table public.import_templates      enable row level security;

create policy "org staff manages outcomes" on public.learning_outcomes
  for all to authenticated
  using ((select public.is_org_staff(org_id)))
  with check ((select public.is_org_staff(org_id)));
create policy "org staff manages templates" on public.import_templates
  for all to authenticated
  using ((select public.is_org_staff(org_id)))
  with check ((select public.is_org_staff(org_id)));
create policy "org staff reads exam imports" on public.exam_imports
  for select to authenticated using ((select public.is_org_staff(org_id)));
create policy "org staff reads exam sheets" on public.exam_sheets
  for select to authenticated using ((select public.is_org_staff(org_id)));
-- Anahtar tabloları: anahtarı görebilen (kurum personeli) görür.
create policy "org staff reads key subjects" on public.answer_key_subjects
  for select to authenticated
  using (exists (select 1 from public.answer_keys k where k.id = key_id));
create policy "org staff reads key classrooms" on public.answer_key_classrooms
  for select to authenticated
  using (exists (select 1 from public.answer_keys k where k.id = key_id));
create policy "org staff reads key booklets" on public.answer_key_booklets
  for select to authenticated
  using (exists (select 1 from public.answer_keys k where k.id = key_id));

do $$
declare t text;
begin
  foreach t in array array['learning_outcomes', 'exam_imports', 'exam_sheets', 'import_templates'] loop
    execute format($f$
      create policy "tenant isolation" on public.%I as restrictive
        for all to public
        using (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
        with check (tenant_id = (select public.my_tenant()) and (select public.my_tenant_active()))
    $f$, t);
  end loop;
end $$;

revoke all on public.learning_outcomes, public.answer_key_subjects, public.answer_key_classrooms,
  public.answer_key_booklets, public.exam_imports, public.exam_sheets, public.import_templates
  from anon;
revoke insert, update, delete, truncate, trigger, references
  on public.answer_key_subjects, public.answer_key_classrooms, public.answer_key_booklets,
     public.exam_imports, public.exam_sheets
  from authenticated;
revoke truncate, trigger, references on public.learning_outcomes, public.import_templates
  from authenticated;
grant select on public.answer_key_subjects, public.answer_key_classrooms,
  public.answer_key_booklets, public.exam_imports, public.exam_sheets to authenticated;
grant select, insert, update, delete on public.learning_outcomes, public.import_templates
  to authenticated;

-- ---------------------------------------------------------------------
-- Puanlama
-- ---------------------------------------------------------------------
create or replace function public.norm_booklet(p text)
returns text
language sql immutable set search_path = ''
as $$
  select case
    when upper(coalesce(trim(p), '')) in ('', 'TEK', '-', '*', '.') then 'A'
    else upper(trim(p)) end
$$;

-- Bir optiğin soru soru değerlendirmesi (yazmaz). Sorular A numarasıyla;
-- booklet_no öğrencinin kendi kitapçığındaki numara (A'da boş).
create or replace function public._score_sheet(p_key uuid, p_answers jsonb, p_booklet text)
returns table (subject_id smallint, question_no smallint, booklet_no smallint,
               marked text, correct text, outcome text, outcome_id uuid,
               topic_id int, touched boolean)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_b text := public.norm_booklet(p_booklet);
begin
  if v_b not in ('A', 'B', 'C', 'D') then
    raise exception 'INVALID_BOOKLET';
  end if;
  if v_b <> 'A' and not exists (
       select 1 from public.answer_key_booklets b
       where b.key_id = p_key and b.booklet = v_b) then
    raise exception 'NO_BOOKLET_KEY';
  end if;
  return query
  with items as (
    select k.subject_id, k.question_no, k.outcome, k.outcome_id, k.topic_id, s.code,
           (k.cancelled or k.correct is null) as cancelled,
           case when v_b = 'A' then null else b.question_no end as bno,
           case when v_b = 'A' then k.correct else coalesce(b.correct, k.correct) end as corr
    from public.answer_key_items k
    join public.subjects s on s.id = k.subject_id
    join public.answer_key_subjects ks
      on ks.key_id = k.key_id and ks.subject_id = k.subject_id
     and k.question_no <= ks.question_count
    left join public.answer_key_booklets b
      on b.key_id = k.key_id and b.subject_id = k.subject_id
     and b.booklet = v_b and b.item_no = k.question_no
    where k.key_id = p_key
  ), marks as (
    select i.*, upper(p_answers -> i.code ->> (coalesce(i.bno, i.question_no) - 1)) as m
    from items i
  )
  select m.subject_id, m.question_no, m.bno::smallint,
         case when m.m in ('A', 'B', 'C', 'D', 'E') then m.m end,
         case when m.cancelled then null else m.corr end,
         m.outcome, m.outcome_id, m.topic_id,
         exists (select 1 from jsonb_array_elements_text(
                   case when jsonb_typeof(p_answers -> m.code) = 'array'
                        then p_answers -> m.code else '[]'::jsonb end) x
                 where upper(x) in ('A', 'B', 'C', 'D', 'E'))
  from marks m;
end;
$$;
revoke all on function public._score_sheet(uuid, jsonb, text) from public, anon, authenticated;

-- Optiği puanlayıp öğrencinin denemesi olarak yazar (deneme varsa yerinde
-- günceller; bildirim yalnızca ilk eklemede gider). Yetki çağıranda.
create or replace function public._apply_sheet(
  p_key uuid, p_student uuid, p_answers jsonb, p_booklet text, p_actor uuid)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_key     public.answer_keys%rowtype;
  v_student public.profiles%rowtype;
  v_b       text := public.norm_booklet(p_booklet);
  v_exam    uuid;
  v_field   public.field_type;
  v_class   uuid;
begin
  select * into v_key from public.answer_keys where id = p_key;
  select * into v_student from public.profiles where id = p_student;
  perform set_config('mentoria.scoring', 'on', true);

  drop table if exists _marks;
  create temp table _marks on commit drop as
    select * from public._score_sheet(p_key, p_answers, v_b);

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

  select cs.classroom_id into v_class
  from public.classroom_students cs where cs.student_id = p_student limit 1;

  select e.id into v_exam from public.exams e
  where e.batch_id = p_key and e.student_id = p_student;

  if v_exam is not null then
    delete from public.exam_subject_results where exam_id = v_exam;
    delete from public.exam_wrong_topics where exam_id = v_exam;
    delete from public.exam_answers where exam_id = v_exam;
    update public.exams
    set name = v_key.name, exam_type = v_key.exam_type, field = v_field,
        publisher = v_key.publisher, taken_on = v_key.taken_on,
        booklet = v_b, classroom_id = v_class
    where id = v_exam;
  else
    insert into public.exams
      (student_id, exam_type, field, name, publisher, taken_on, created_by,
       source, batch_id, booklet, classroom_id)
    values (p_student, v_key.exam_type, v_field, v_key.name, v_key.publisher,
            v_key.taken_on, p_actor, 'optic', p_key, v_b, v_class)
    returning id into v_exam;
  end if;

  -- TYT'de tüm dersler, AYT/YDT'de yalnızca işaret konan dersler sayılır.
  insert into public.exam_answers
    (exam_id, subject_id, question_no, booklet_no, marked, correct, outcome,
     outcome_id, topic_id)
  select v_exam, m.subject_id, m.question_no, m.booklet_no, m.marked, m.correct,
         m.outcome, m.outcome_id, m.topic_id
  from _marks m
  where v_key.exam_type = 'TYT' or m.touched;

  -- İptal sorular (doğru cevabı boş) hiçbir sayıma girmez.
  insert into public.exam_subject_results
    (exam_id, subject_id, correct, wrong, blank, wrong_penalty, weight)
  select v_exam, a.subject_id,
         count(*) filter (where a.marked = a.correct),
         count(*) filter (where a.marked is not null and a.marked <> a.correct),
         count(*) filter (where a.marked is null),
         case when v_key.wrong_penalty then v_key.penalty_ratio else 0 end,
         coalesce(max(ks.weight), 1)
  from public.exam_answers a
  left join public.answer_key_subjects ks on ks.key_id = p_key and ks.subject_id = a.subject_id
  where a.exam_id = v_exam and a.correct is not null
  group by a.subject_id;

  insert into public.exam_wrong_topics (exam_id, topic_id, count)
  select v_exam, a.topic_id, count(*)
  from public.exam_answers a
  where a.exam_id = v_exam and a.topic_id is not null and a.correct is not null
    and (a.marked is null or a.marked <> a.correct)
  group by a.topic_id;

  update public.exams
  set total_net = (select coalesce(sum(r.net * r.weight), 0)
                   from public.exam_subject_results r where r.exam_id = v_exam)
  where id = v_exam;
  return v_exam;
end;
$$;
revoke all on function public._apply_sheet(uuid, uuid, jsonb, text, uuid) from public, anon, authenticated;

-- Kurum ve sınıf sıralaması (toplam net ve ders neti).
create or replace function public._rank_key(p_key uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  perform set_config('mentoria.scoring', 'on', true);
  update public.exams e
  set rank_org = r.ro, rank_class = r.rc
  from (select x.id,
               rank() over (order by x.total_net desc nulls last) ro,
               case when x.classroom_id is null then null
                    else rank() over (partition by x.classroom_id
                                      order by x.total_net desc nulls last) end rc
        from public.exams x where x.batch_id = p_key and x.source = 'optic') r
  where e.id = r.id;
  update public.exam_subject_results t
  set rank_org = r.ro, rank_class = r.rc
  from (select x.exam_id, x.subject_id,
               rank() over (partition by x.subject_id order by x.net desc) ro,
               case when e.classroom_id is null then null
                    else rank() over (partition by x.subject_id, e.classroom_id
                                      order by x.net desc) end rc
        from public.exam_subject_results x
        join public.exams e on e.id = x.exam_id
        where e.batch_id = p_key and e.source = 'optic') r
  where t.exam_id = r.exam_id and t.subject_id = r.subject_id;
end;
$$;
revoke all on function public._rank_key(uuid) from public, anon, authenticated;

-- Yayındaki sınavın tüm optiklerini yeniden puanlar.
create or replace function public._rescore_key(p_key uuid)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  n int := 0;
begin
  for r in select * from public.exam_sheets where key_id = p_key loop
    begin
      perform public._apply_sheet(p_key, r.student_id, r.answers, r.booklet, auth.uid());
      n := n + 1;
    exception when others then
      -- Kitapçığı artık anahtarda olmayan optik: atlanır.
      if sqlerrm not in ('NO_BOOKLET_KEY', 'INVALID_BOOKLET') then
        raise;
      end if;
    end;
  end loop;
  perform public._rank_key(p_key);
  return n;
end;
$$;
revoke all on function public._rescore_key(uuid) from public, anon, authenticated;

-- Mevcut optik denemeler: toplam net ve sıralama.
do $$
declare k uuid;
begin
  perform set_config('mentoria.scoring', 'on', true);
  update public.exams e
  set total_net = (select coalesce(sum(r.net), 0) from public.exam_subject_results r
                   where r.exam_id = e.id)
  where e.source = 'optic';
  for k in select distinct batch_id from public.exams
           where source = 'optic' and batch_id is not null loop
    perform public._rank_key(k);
  end loop;
end $$;

-- Sınava yazma yetkisi: kurum personeli; anahtarı müdür ya da ekleyen düzenler.
create or replace function public._key_for_write(p_key uuid)
returns public.answer_keys
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_key public.answer_keys%rowtype;
begin
  select * into v_key from public.answer_keys
  where id = p_key and tenant_id = public.my_tenant();
  if not found or not public.is_org_staff(v_key.org_id) then
    raise exception 'KEY_NOT_FOUND';
  end if;
  if public.my_role() <> 'admin' and v_key.created_by is distinct from auth.uid() then
    raise exception 'NOT_ALLOWED';
  end if;
  return v_key;
end;
$$;
revoke all on function public._key_for_write(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Sınav tanımı: bilgiler + dersler + anahtar + kazanımlar + kitapçıklar
-- ---------------------------------------------------------------------
-- p_def: {"name", "exam_type", "kind", "publisher", "taken_on",
--   "wrong_penalty", "penalty_ratio", "template_id", "classrooms": [uuid],
--   "subjects": [{"subject": "TYT_MAT", "count": 40, "weight": 1}],
--   "items": [{"subject", "no", "correct", "outcome_id", "outcome",
--              "topic_id", "difficulty", "cancelled"}],
--   "booklets": {"B": [{"subject", "no", "item_no", "correct"}]}}
-- Yayındaki sınavda kaydedince tüm optikler yeniden puanlanır.
create or replace function public.save_exam(p_key uuid, p_def jsonb)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_key   public.answer_keys%rowtype;
  v_type  public.exam_type;
  v_id    uuid;
  v_bad   int;
  v_ratio numeric;
begin
  if public.my_role() not in ('coach', 'admin') or public.my_org() is null
     or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  if jsonb_typeof(p_def) <> 'object'
     or length(trim(coalesce(p_def->>'name', ''))) not between 2 and 80 then
    raise exception 'INVALID_EXAM';
  end if;
  v_type := (p_def->>'exam_type')::public.exam_type;
  v_ratio := coalesce((p_def->>'penalty_ratio')::numeric, 0.25);
  if v_ratio not between 0 and 1
     or coalesce(p_def->>'kind', 'deneme') not in ('deneme', 'konu_tarama') then
    raise exception 'INVALID_EXAM';
  end if;
  if p_key is not null then
    v_key := public._key_for_write(p_key);
    if v_key.exam_type <> v_type then
      raise exception 'TYPE_LOCKED';
    end if;
  end if;

  -- Dersler: bu sınav türünün dersi, 1-80 soru, katsayı (0, 10].
  if jsonb_typeof(p_def->'subjects') <> 'array' or jsonb_array_length(p_def->'subjects') = 0 then
    raise exception 'NO_SUBJECTS';
  end if;
  select count(*) into v_bad
  from jsonb_array_elements(p_def->'subjects') x
  left join public.subjects s on s.code = x->>'subject' and s.exam_type = v_type
  where s.id is null
     or coalesce((x->>'count')::int, 0) not between 1 and 80
     or coalesce((x->>'weight')::numeric, 1) <= 0 or coalesce((x->>'weight')::numeric, 1) > 10;
  if v_bad = 0 then
    select count(*) into v_bad from (
      select x->>'subject' from jsonb_array_elements(p_def->'subjects') x
      group by 1 having count(*) > 1) d;
  end if;
  if v_bad > 0 then
    raise exception 'INVALID_SUBJECTS';
  end if;

  -- Sorular: dersi sınavda, no ders soru sayısını aşmıyor, kazanım
  -- kurumun ve aynı dersin.
  select count(*) into v_bad
  from jsonb_array_elements(coalesce(p_def->'items', '[]'::jsonb)) i
  left join jsonb_array_elements(p_def->'subjects') x on x->>'subject' = i->>'subject'
  left join public.learning_outcomes o on o.id = (i->>'outcome_id')::uuid
  left join public.subjects s on s.code = i->>'subject'
  where x is null
     or coalesce((i->>'no')::int, 0) not between 1 and (x->>'count')::int
     or (nullif(trim(i->>'correct'), '') is not null
         and upper(trim(i->>'correct')) not in ('A', 'B', 'C', 'D', 'E'))
     or coalesce(i->>'difficulty', 'easy') not in ('easy', 'medium', 'hard')
     or (i->>'outcome_id' is not null
         and (o.id is null or o.org_id <> public.my_org() or o.subject_id <> s.id));
  if v_bad = 0 then
    select count(*) into v_bad from (
      select i->>'subject', i->>'no' from jsonb_array_elements(coalesce(p_def->'items', '[]'::jsonb)) i
      group by 1, 2 having count(*) > 1) d;
  end if;
  if v_bad > 0 then
    raise exception 'INVALID_ITEMS';
  end if;

  -- Kitapçıklar: B/C/D; numaralar ders soru sayısı içinde ve tekrarsız.
  if p_def ? 'booklets' and jsonb_typeof(p_def->'booklets') = 'object' then
    if exists (select 1 from jsonb_each(p_def->'booklets') bk
               where bk.key not in ('B', 'C', 'D') or jsonb_typeof(bk.value) <> 'array') then
      raise exception 'INVALID_BOOKLETS';
    end if;
    select count(*) into v_bad
    from jsonb_each(p_def->'booklets') bk
    cross join lateral jsonb_array_elements(
      case when jsonb_typeof(bk.value) = 'array' then bk.value else '[]'::jsonb end) b
    left join jsonb_array_elements(p_def->'subjects') x on x->>'subject' = b->>'subject'
    where bk.key not in ('B', 'C', 'D') or jsonb_typeof(bk.value) <> 'array' or x is null
       or coalesce((b->>'no')::int, 0) not between 1 and (x->>'count')::int
       or coalesce((b->>'item_no')::int, 0) not between 1 and (x->>'count')::int
       or (nullif(trim(b->>'correct'), '') is not null
           and upper(trim(b->>'correct')) not in ('A', 'B', 'C', 'D', 'E'));
    if v_bad = 0 then
      select count(*) into v_bad from (
        select bk.key, b->>'subject', b->>'no'
        from jsonb_each(p_def->'booklets') bk, jsonb_array_elements(bk.value) b
        group by 1, 2, 3 having count(*) > 1
        union all
        select bk.key, b->>'subject', b->>'item_no'
        from jsonb_each(p_def->'booklets') bk, jsonb_array_elements(bk.value) b
        group by 1, 2, 3 having count(*) > 1) d;
    end if;
    if v_bad > 0 then
      raise exception 'INVALID_BOOKLETS';
    end if;
  end if;

  if p_key is null then
    insert into public.answer_keys
      (tenant_id, org_id, created_by, name, exam_type, publisher, taken_on,
       template_id, kind, status, wrong_penalty, penalty_ratio)
    values (public.my_tenant(), public.my_org(), auth.uid(), trim(p_def->>'name'), v_type,
            nullif(trim(p_def->>'publisher'), ''),
            coalesce((p_def->>'taken_on')::date, current_date),
            coalesce(nullif(p_def->>'template_id', ''), 'standart_yks'),
            coalesce(p_def->>'kind', 'deneme'), 'draft',
            coalesce((p_def->>'wrong_penalty')::boolean, true), v_ratio)
    returning id into v_id;
  else
    v_id := p_key;
    update public.answer_keys
    set name = trim(p_def->>'name'),
        publisher = nullif(trim(p_def->>'publisher'), ''),
        taken_on = coalesce((p_def->>'taken_on')::date, taken_on),
        template_id = coalesce(nullif(p_def->>'template_id', ''), template_id),
        kind = coalesce(p_def->>'kind', kind),
        wrong_penalty = coalesce((p_def->>'wrong_penalty')::boolean, wrong_penalty),
        penalty_ratio = v_ratio
    where id = v_id;
    delete from public.answer_key_subjects where key_id = v_id;
    delete from public.answer_key_items where key_id = v_id;
    delete from public.answer_key_booklets where key_id = v_id;
    delete from public.answer_key_classrooms where key_id = v_id;
  end if;

  insert into public.answer_key_subjects (key_id, subject_id, question_count, sort, weight)
  select v_id, s.id, (x->>'count')::smallint, (o - 1)::smallint,
         coalesce((x->>'weight')::numeric, 1)
  from jsonb_array_elements(p_def->'subjects') with ordinality t(x, o)
  join public.subjects s on s.code = x->>'subject';

  insert into public.answer_key_classrooms (key_id, classroom_id)
  select distinct v_id, c.id
  from jsonb_array_elements_text(coalesce(p_def->'classrooms', '[]'::jsonb)) x
  join public.classrooms c on c.id = x::uuid and c.org_id = public.my_org();

  insert into public.answer_key_items
    (key_id, subject_id, question_no, correct, outcome, outcome_id, topic_id,
     difficulty, cancelled)
  select v_id, s.id, (i->>'no')::smallint,
         nullif(upper(trim(i->>'correct')), ''),
         left(coalesce(public.outcome_label((i->>'outcome_id')::uuid),
                       nullif(trim(i->>'outcome'), '')), 300),
         (i->>'outcome_id')::uuid,
         coalesce(public.outcome_topic((i->>'outcome_id')::uuid), t.id),
         i->>'difficulty',
         coalesce((i->>'cancelled')::boolean, false)
  from jsonb_array_elements(coalesce(p_def->'items', '[]'::jsonb)) i
  join public.subjects s on s.code = i->>'subject'
  left join public.topics t on t.id = (i->>'topic_id')::int and t.subject_id = s.id;

  if p_def ? 'booklets' and jsonb_typeof(p_def->'booklets') = 'object' then
    insert into public.answer_key_booklets
      (key_id, subject_id, booklet, question_no, item_no, correct)
    select v_id, s.id, bk.key, (b->>'no')::smallint, (b->>'item_no')::smallint,
           nullif(upper(trim(b->>'correct')), '')
    from jsonb_each(p_def->'booklets') bk
    cross join lateral jsonb_array_elements(bk.value) b
    join public.subjects s on s.code = b->>'subject';
  end if;

  -- Kamerayla okuma (submit_optic eski sürümü) B numarasını buradan da okur.
  update public.answer_key_items i
  set question_no_b = b.question_no
  from public.answer_key_booklets b
  where i.key_id = v_id and b.key_id = v_id and b.booklet = 'B'
    and b.subject_id = i.subject_id and b.item_no = i.question_no;

  if p_key is not null and v_key.status = 'published' then
    perform public._rescore_key(v_id);
  end if;
  return v_id;
end;
$$;
revoke execute on function public.save_exam(uuid, jsonb) from public, anon;
grant execute on function public.save_exam(uuid, jsonb) to authenticated;

-- Taslak sınavı yayınlar: optikler puanlanır, öğrenciye bildirim gider.
create or replace function public.publish_exam(p_key uuid)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_key public.answer_keys%rowtype;
begin
  v_key := public._key_for_write(p_key);
  if v_key.status = 'published' then
    raise exception 'ALREADY_PUBLISHED';
  end if;
  if not exists (select 1 from public.answer_key_items
                 where key_id = p_key and correct is not null and not cancelled) then
    raise exception 'NO_ITEMS';
  end if;
  update public.answer_keys set status = 'published', published_at = now() where id = p_key;
  return public._rescore_key(p_key);
end;
$$;
revoke execute on function public.publish_exam(uuid) from public, anon;
grant execute on function public.publish_exam(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Excel içe aktarma: başlat → parçalar → bitir
-- ---------------------------------------------------------------------
-- p_stats: {"rows", "matched", "unmatched", "failed", "log": {...}}
create or replace function public.start_exam_import(p_key uuid, p_file text, p_stats jsonb)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_key public.answer_keys%rowtype;
  v_id  uuid;
begin
  select * into v_key from public.answer_keys
  where id = p_key and tenant_id = public.my_tenant();
  if not found or not public.is_org_staff(v_key.org_id) then
    raise exception 'KEY_NOT_FOUND';
  end if;
  insert into public.exam_imports
    (key_id, org_id, tenant_id, file_name, created_by, row_count, matched,
     unmatched, failed, log)
  values (p_key, v_key.org_id, v_key.tenant_id, left(p_file, 200), auth.uid(),
          coalesce((p_stats->>'rows')::int, 0), coalesce((p_stats->>'matched')::int, 0),
          coalesce((p_stats->>'unmatched')::int, 0), coalesce((p_stats->>'failed')::int, 0),
          coalesce(p_stats->'log', '{}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.start_exam_import(uuid, text, jsonb) from public, anon;
grant execute on function public.start_exam_import(uuid, text, jsonb) to authenticated;

-- p_rows: [{"student_id", "booklet", "answers": {"TYT_MAT": ["A", null, ...]}}]
-- En çok 100 satır. Kurumun öğrencisi olmayan ya da kitapçığı anahtarda
-- olmayan satır atlanır (skipped). Aynı öğrencinin optiği güncellenir.
create or replace function public.import_exam_sheets(p_import uuid, p_rows jsonb)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_imp     public.exam_imports%rowtype;
  v_key     public.answer_keys%rowtype;
  r         jsonb;
  v_student uuid;
  v_booklet text;
  v_saved   int := 0;
  v_skipped jsonb := '[]'::jsonb;
begin
  select * into v_imp from public.exam_imports
  where id = p_import and tenant_id = public.my_tenant();
  if not found or not public.is_org_staff(v_imp.org_id) or v_imp.status <> 'running' then
    raise exception 'IMPORT_NOT_FOUND';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 100 then
    raise exception 'INVALID_ROWS';
  end if;
  select * into v_key from public.answer_keys where id = v_imp.key_id;

  for r in select * from jsonb_array_elements(p_rows) loop
    v_student := (r->>'student_id')::uuid;
    v_booklet := public.norm_booklet(r->>'booklet');
    if not exists (select 1 from public.profiles p
                   where p.id = v_student and p.role = 'student' and p.org_id = v_imp.org_id) then
      v_skipped := v_skipped || jsonb_build_object('student_id', v_student, 'reason', 'NOT_STUDENT');
      continue;
    end if;
    if v_booklet not in ('A', 'B', 'C', 'D')
       or (v_booklet <> 'A' and not exists (
             select 1 from public.answer_key_booklets b
             where b.key_id = v_key.id and b.booklet = v_booklet)) then
      v_skipped := v_skipped || jsonb_build_object('student_id', v_student, 'reason', 'NO_BOOKLET_KEY');
      continue;
    end if;
    if jsonb_typeof(r->'answers') <> 'object' then
      v_skipped := v_skipped || jsonb_build_object('student_id', v_student, 'reason', 'INVALID_ANSWERS');
      continue;
    end if;
    insert into public.exam_sheets
      (key_id, student_id, org_id, tenant_id, booklet, answers, source, import_id, updated_at)
    values (v_key.id, v_student, v_key.org_id, v_key.tenant_id, v_booklet, r->'answers',
            'import', p_import, now())
    on conflict (key_id, student_id) do update
      set booklet = excluded.booklet, answers = excluded.answers, source = 'import',
          import_id = excluded.import_id, updated_at = now();
    if v_key.status = 'published' then
      perform public._apply_sheet(v_key.id, v_student, r->'answers', v_booklet, auth.uid());
    end if;
    v_saved := v_saved + 1;
  end loop;

  update public.exam_imports set saved = saved + v_saved where id = p_import;
  return jsonb_build_object('saved', v_saved, 'skipped', v_skipped);
end;
$$;
revoke execute on function public.import_exam_sheets(uuid, jsonb) from public, anon;
grant execute on function public.import_exam_sheets(uuid, jsonb) to authenticated;

create or replace function public.finish_exam_import(p_import uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_imp public.exam_imports%rowtype;
  v_key public.answer_keys%rowtype;
begin
  select * into v_imp from public.exam_imports
  where id = p_import and tenant_id = public.my_tenant();
  if not found or not public.is_org_staff(v_imp.org_id) then
    raise exception 'IMPORT_NOT_FOUND';
  end if;
  select * into v_key from public.answer_keys where id = v_imp.key_id;
  if v_key.status = 'published' then
    perform public._rank_key(v_key.id);
  end if;
  update public.exam_imports set status = 'done' where id = p_import;
  return jsonb_build_object(
    'saved', v_imp.saved,
    'sheets', (select count(*) from public.exam_sheets where key_id = v_key.id),
    'published', v_key.status = 'published');
end;
$$;
revoke execute on function public.finish_exam_import(uuid) from public, anon;
grant execute on function public.finish_exam_import(uuid) to authenticated;

-- Kazanım havuzu toplu ekleme: [{"subject": "TYT_MAT", "topic", "subtopic",
-- "code"}]. Aynı ad (yazım farkı gözetmeden) tekrar eklenmez.
create or replace function public.import_learning_outcomes(p_rows jsonb)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  r        jsonb;
  v_sub    smallint;
  v_parent uuid;
  v_child  uuid;
  v_ins    int := 0;
  v_skip   int := 0;
  v_org    uuid := public.my_org();
begin
  if not public.is_org_staff(v_org) then
    raise exception 'NOT_ALLOWED';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 3000 then
    raise exception 'INVALID_ROWS';
  end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    select id into v_sub from public.subjects where code = r->>'subject';
    if v_sub is null or length(trim(coalesce(r->>'topic', ''))) = 0 then
      v_skip := v_skip + 1;
      continue;
    end if;
    select id into v_parent from public.learning_outcomes
    where org_id = v_org and subject_id = v_sub and parent_id is null
      and public.norm_key(name) = public.norm_key(r->>'topic');
    if v_parent is null then
      insert into public.learning_outcomes (org_id, subject_id, name, code, topic_id)
      values (v_org, v_sub, left(trim(r->>'topic'), 200),
              case when nullif(trim(r->>'subtopic'), '') is null then left(r->>'code', 40) end,
              (select t.id from public.topics t
               where t.subject_id = v_sub and public.norm_key(t.name) = public.norm_key(r->>'topic')
               limit 1))
      returning id into v_parent;
      v_ins := v_ins + 1;
    elsif nullif(trim(r->>'subtopic'), '') is null then
      v_skip := v_skip + 1;
    end if;
    if nullif(trim(r->>'subtopic'), '') is not null then
      select id into v_child from public.learning_outcomes
      where parent_id = v_parent and public.norm_key(name) = public.norm_key(r->>'subtopic');
      if v_child is null then
        insert into public.learning_outcomes (org_id, subject_id, parent_id, name, code)
        values (v_org, v_sub, v_parent, left(trim(r->>'subtopic'), 200), left(r->>'code', 40));
        v_ins := v_ins + 1;
      else
        v_skip := v_skip + 1;
      end if;
      v_child := null;
    end if;
    v_parent := null;
  end loop;
  return jsonb_build_object('inserted', v_ins, 'skipped', v_skip);
end;
$$;
revoke execute on function public.import_learning_outcomes(jsonb) from public, anon;
grant execute on function public.import_learning_outcomes(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- Kamerayla okuma: ham optik + (yayındaysa) puanlama
-- ---------------------------------------------------------------------
drop function public.submit_optic(uuid, uuid, jsonb, text);

-- Taslak sınavda yalnızca ham optik kaydedilir; dönüşte exam_id boş,
-- doğru/yanlış/boş/net önizlemedir.
create or replace function public.submit_optic(
  p_key uuid, p_student uuid, p_answers jsonb, p_booklet text default 'A')
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_key     public.answer_keys%rowtype;
  v_b       text := public.norm_booklet(p_booklet);
  v_exam    uuid;
  v_created timestamptz;
  v_updated boolean;
  v_sum     record;
begin
  if public.my_role() not in ('coach', 'admin') or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_b not in ('A', 'B', 'C', 'D') then
    raise exception 'INVALID_BOOKLET';
  end if;
  select * into v_key from public.answer_keys
  where id = p_key and org_id = public.my_org() and tenant_id = public.my_tenant();
  if not found then
    raise exception 'KEY_NOT_FOUND';
  end if;
  if not exists (select 1 from public.profiles where id = p_student and role = 'student')
     or not public.can_manage_student(p_student) then
    raise exception 'NOT_ALLOWED';
  end if;
  if jsonb_typeof(p_answers) <> 'object' then
    raise exception 'INVALID_ANSWERS';
  end if;
  if v_b <> 'A' and not exists (select 1 from public.answer_key_booklets
                                where key_id = p_key and booklet = v_b) then
    raise exception 'NO_B_KEY';
  end if;

  select e.id, e.created_at into v_exam, v_created
  from public.exams e where e.batch_id = p_key and e.student_id = p_student;
  if v_exam is not null and not public.exam_editable(v_created) then
    raise exception 'EXAM_LOCKED';
  end if;
  v_updated := v_exam is not null
    or exists (select 1 from public.exam_sheets where key_id = p_key and student_id = p_student);

  insert into public.exam_sheets
    (key_id, student_id, org_id, tenant_id, booklet, answers, source, updated_at)
  values (p_key, p_student, v_key.org_id, v_key.tenant_id, v_b, p_answers, 'optic', now())
  on conflict (key_id, student_id) do update
    set booklet = excluded.booklet, answers = excluded.answers, source = 'optic',
        import_id = null, updated_at = now();

  if v_key.status = 'published' then
    v_exam := public._apply_sheet(p_key, p_student, p_answers, v_b, auth.uid());
    perform public._rank_key(p_key);
    select coalesce(sum(r.correct), 0)::int as c, coalesce(sum(r.wrong), 0)::int as w,
           coalesce(sum(r.blank), 0)::int as b, coalesce(sum(r.net * r.weight), 0) as n
    into v_sum from public.exam_subject_results r where r.exam_id = v_exam;
  else
    v_exam := null;
    select coalesce(sum(x.c), 0)::int as c, coalesce(sum(x.w), 0)::int as w,
           coalesce(sum(x.b), 0)::int as b,
           round(coalesce(sum(round(x.c - x.w * case when v_key.wrong_penalty then v_key.penalty_ratio else 0 end, 2)
                              * coalesce(ks.weight, 1)), 0), 2) as n
    into v_sum
    from (select m.subject_id,
                 count(*) filter (where m.marked = m.correct) c,
                 count(*) filter (where m.marked is not null and m.marked <> m.correct) w,
                 count(*) filter (where m.marked is null) b
          from public._score_sheet(p_key, p_answers, v_b) m
          where m.correct is not null and (v_key.exam_type = 'TYT' or m.touched)
          group by m.subject_id) x
    left join public.answer_key_subjects ks on ks.key_id = p_key and ks.subject_id = x.subject_id;
  end if;

  return jsonb_build_object('exam_id', v_exam, 'updated', v_updated,
    'correct', v_sum.c, 'wrong', v_sum.w, 'blank', v_sum.b, 'net', v_sum.n);
end;
$$;
revoke execute on function public.submit_optic(uuid, uuid, jsonb, text) from public, anon;
grant execute on function public.submit_optic(uuid, uuid, jsonb, text) to authenticated;

-- Excel kazanım tablosuyla anahtar (kamera akışı): dersler müfredat soru
-- sayısıyla, B numaraları kitapçık tablosuna da yazılır.
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

  insert into public.answer_key_subjects (key_id, subject_id, question_count, sort)
  select distinct v_id, s.id, s.question_count, s.sort
  from public.answer_key_items i join public.subjects s on s.id = i.subject_id
  where i.key_id = v_id;
  insert into public.answer_key_booklets (key_id, subject_id, booklet, question_no, item_no)
  select v_id, subject_id, 'B', question_no_b, question_no
  from public.answer_key_items where key_id = v_id and question_no_b is not null;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------
-- Kazanım analizi görünümleri (okuyanın yetkisiyle: öğrenci kendini,
-- koç kendi öğrencilerini, müdür kurumu görür)
-- ---------------------------------------------------------------------
-- Net kaybı: yanlış (1 + yanlış katsayısı), boş 1 net; ders katsayısıyla.
create view public.v_student_outcome_analysis with (security_invoker = true) as
select e.student_id, e.id as exam_id, e.batch_id as key_id, e.taken_on, e.exam_type,
       e.classroom_id, a.subject_id, a.outcome_id,
       coalesce(a.outcome_id::text, public.norm_key(a.outcome)) as outcome_key,
       min(a.outcome) as outcome,
       count(*)::int as questions,
       count(*) filter (where a.marked = a.correct)::int as correct,
       count(*) filter (where a.marked is not null and a.marked <> a.correct)::int as wrong,
       count(*) filter (where a.marked is null)::int as blank,
       round(100.0 * count(*) filter (where a.marked = a.correct) / count(*), 1) as success_pct,
       round(sum((case when a.marked is null then 1
                       when a.marked <> a.correct then 1 + r.wrong_penalty
                       else 0 end) * r.weight), 2) as lost_net
from public.exam_answers a
join public.exams e on e.id = a.exam_id
join public.exam_subject_results r on r.exam_id = a.exam_id and r.subject_id = a.subject_id
where a.correct is not null and coalesce(trim(a.outcome), '') <> ''
group by e.student_id, e.id, e.batch_id, e.taken_on, e.exam_type, e.classroom_id,
         a.subject_id, a.outcome_id, coalesce(a.outcome_id::text, public.norm_key(a.outcome));

create view public.v_class_outcome_analysis with (security_invoker = true) as
select key_id, classroom_id, subject_id, outcome_key, min(outcome) as outcome,
       count(distinct student_id)::int as students,
       sum(questions)::int as questions, sum(correct)::int as correct,
       sum(wrong)::int as wrong, sum(blank)::int as blank,
       round(100.0 * sum(correct) / nullif(sum(questions), 0), 1) as success_pct,
       round(avg(lost_net), 2) as avg_lost_net
from public.v_student_outcome_analysis
where key_id is not null and classroom_id is not null
group by key_id, classroom_id, subject_id, outcome_key;

create view public.v_institution_outcome_analysis with (security_invoker = true) as
select key_id, subject_id, outcome_key, min(outcome) as outcome,
       count(distinct student_id)::int as students,
       sum(questions)::int as questions, sum(correct)::int as correct,
       sum(wrong)::int as wrong, sum(blank)::int as blank,
       round(100.0 * sum(correct) / nullif(sum(questions), 0), 1) as success_pct,
       round(avg(lost_net), 2) as avg_lost_net
from public.v_student_outcome_analysis
where key_id is not null
group by key_id, subject_id, outcome_key;

-- Soru zorluğu: doğru / boş yüzdesi, en çok işaretlenen yanlış şık ve
-- ayırt edicilik (en iyi %27'nin doğru oranı − en zayıf %27'ninki; sıfırın
-- altındaysa anahtar hatalı olabilir).
create view public.v_question_difficulty with (security_invoker = true) as
with x as (
  select e.batch_id as key_id, a.subject_id, a.question_no, a.marked, a.correct,
         min(a.outcome) over (partition by e.batch_id, a.subject_id, a.question_no) as outcome,
         percent_rank() over (partition by e.batch_id, a.subject_id, a.question_no
                              order by e.total_net desc nulls last) as pr
  from public.exam_answers a
  join public.exams e on e.id = a.exam_id
  where e.source = 'optic' and e.batch_id is not null and a.correct is not null
)
select key_id, subject_id, question_no, min(correct) as correct_answer, min(outcome) as outcome,
       count(*)::int as students,
       round(100.0 * avg(coalesce((marked = correct)::int, 0)), 1) as correct_pct,
       round(100.0 * avg((marked is null)::int), 1) as blank_pct,
       mode() within group (order by marked) filter (where marked <> correct) as top_wrong,
       round((avg(coalesce((marked = correct)::int, 0)) filter (where pr <= 0.27)
              - avg(coalesce((marked = correct)::int, 0)) filter (where pr >= 0.73))::numeric, 2)
         as discrimination
from x
group by key_id, subject_id, question_no;

revoke all on public.v_student_outcome_analysis, public.v_class_outcome_analysis,
  public.v_institution_outcome_analysis, public.v_question_difficulty from anon;
grant select on public.v_student_outcome_analysis, public.v_class_outcome_analysis,
  public.v_institution_outcome_analysis, public.v_question_difficulty to authenticated;

-- ---------------------------------------------------------------------
-- Raporlar
-- ---------------------------------------------------------------------
-- Sınıf ve kurum raporu (kurum personeli). Koç kurum geneli ortalamaları
-- görür; sıralama listesinde yalnızca kendi öğrencileri (müdür hepsini).
create or replace function public.exam_report(p_key uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_key   public.answer_keys%rowtype;
  v_admin boolean;
begin
  select * into v_key from public.answer_keys
  where id = p_key and tenant_id = public.my_tenant();
  if not found or not public.is_org_staff(v_key.org_id) then
    raise exception 'KEY_NOT_FOUND';
  end if;
  v_admin := public.my_role() = 'admin';

  return jsonb_build_object(
    'students', (select count(*) from public.exams where batch_id = p_key and source = 'optic'),
    'avg_net', (select round(avg(total_net), 2) from public.exams
                where batch_id = p_key and source = 'optic'),
    'max_net', (select max(total_net) from public.exams where batch_id = p_key and source = 'optic'),
    'min_net', (select min(total_net) from public.exams where batch_id = p_key and source = 'optic'),
    'subjects', coalesce((
      select jsonb_agg(jsonb_build_object(
               'subject_id', s.subject_id, 'avg_net', s.avg_net, 'avg_correct', s.avg_c,
               'avg_wrong', s.avg_w, 'avg_blank', s.avg_b, 'histogram', s.hist)
             order by s.subject_id)
      from (select r.subject_id,
                   round(avg(r.net), 2) avg_net, round(avg(r.correct), 1) avg_c,
                   round(avg(r.wrong), 1) avg_w, round(avg(r.blank), 1) avg_b,
                   (select jsonb_object_agg(b.bucket, b.n) from (
                      select (floor(r2.net / 5) * 5)::int::text bucket, count(*) n
                      from public.exam_subject_results r2 join public.exams e2 on e2.id = r2.exam_id
                      where e2.batch_id = p_key and e2.source = 'optic' and r2.subject_id = r.subject_id
                      group by 1) b) hist
            from public.exam_subject_results r join public.exams e on e.id = r.exam_id
            where e.batch_id = p_key and e.source = 'optic'
            group by r.subject_id) s), '[]'::jsonb),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'classroom_id', c.id, 'name', c.name, 'students', x.n, 'avg_net', x.avg_net,
               'subjects', x.subj)
             order by x.avg_net desc nulls last)
      from (select e.classroom_id, count(*) n, round(avg(e.total_net), 2) avg_net,
                   (select jsonb_object_agg(q.subject_id, q.a) from (
                      select r.subject_id, round(avg(r.net), 2) a
                      from public.exam_subject_results r join public.exams e3 on e3.id = r.exam_id
                      where e3.batch_id = p_key and e3.source = 'optic'
                        and e3.classroom_id = e.classroom_id
                      group by r.subject_id) q) subj
            from public.exams e
            where e.batch_id = p_key and e.source = 'optic' and e.classroom_id is not null
            group by e.classroom_id) x
      join public.classrooms c on c.id = x.classroom_id), '[]'::jsonb),
    'weak_outcomes', coalesce((
      select jsonb_agg(to_jsonb(o) order by o.success_pct, o.avg_lost_net desc)
      from (select subject_id, outcome_key, outcome, students, questions, success_pct, avg_lost_net
            from public.v_institution_outcome_analysis
            where key_id = p_key
            order by success_pct, avg_lost_net desc limit 10) o), '[]'::jsonb),
    'class_outcomes', coalesce((
      select jsonb_agg(to_jsonb(o))
      from (select classroom_id, subject_id, outcome_key, outcome, students, success_pct,
                   avg_lost_net,
                   row_number() over (partition by classroom_id
                                      order by success_pct, avg_lost_net desc) rn
            from public.v_class_outcome_analysis where key_id = p_key) o
      where o.rn <= 5), '[]'::jsonb),
    'questions', coalesce((
      select jsonb_agg(to_jsonb(q) order by q.subject_id, q.question_no)
      from public.v_question_difficulty q where q.key_id = p_key), '[]'::jsonb),
    'ranking', coalesce((
      select jsonb_agg(jsonb_build_object(
               'exam_id', e.id, 'student_id', e.student_id, 'name', p.full_name,
               'student_number', p.student_number, 'classroom_id', e.classroom_id,
               'booklet', e.booklet, 'total_net', e.total_net, 'rank_org', e.rank_org,
               'rank_class', e.rank_class,
               'subjects', (select jsonb_object_agg(r.subject_id, jsonb_build_object(
                              'c', r.correct, 'w', r.wrong, 'b', r.blank, 'net', r.net))
                            from public.exam_subject_results r where r.exam_id = e.id))
             order by e.rank_org nulls last)
      from public.exams e join public.profiles p on p.id = e.student_id
      where e.batch_id = p_key and e.source = 'optic'
        and (v_admin or public.is_coach_of(e.student_id))), '[]'::jsonb)
  );
end;
$$;
revoke execute on function public.exam_report(uuid) from public, anon;
grant execute on function public.exam_report(uuid) to authenticated;

-- Karne için kurum / sınıf kişi sayısı ve ortalamalar (denemeyi görebilen).
create or replace function public.exam_card_context(p_exam uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_exam public.exams%rowtype;
begin
  select * into v_exam from public.exams where id = p_exam;
  if not found or not public.can_view_student(v_exam.student_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_exam.batch_id is null or v_exam.source <> 'optic' then
    return null;
  end if;
  return jsonb_build_object(
    'org_count', (select count(*) from public.exams where batch_id = v_exam.batch_id and source = 'optic'),
    'class_count', (select count(*) from public.exams where batch_id = v_exam.batch_id
                    and source = 'optic' and classroom_id = v_exam.classroom_id),
    'class_name', (select name from public.classrooms where id = v_exam.classroom_id),
    'org_avg', (select round(avg(total_net), 2) from public.exams
                where batch_id = v_exam.batch_id and source = 'optic'),
    'class_avg', (select round(avg(total_net), 2) from public.exams
                  where batch_id = v_exam.batch_id and source = 'optic'
                    and classroom_id = v_exam.classroom_id),
    'subjects', (select jsonb_object_agg(x.subject_id, jsonb_build_object(
                          'org_avg', x.o, 'class_avg', x.c))
                 from (select r.subject_id, round(avg(r.net), 2) o,
                              round(avg(r.net) filter (where e.classroom_id = v_exam.classroom_id), 2) c
                       from public.exam_subject_results r join public.exams e on e.id = r.exam_id
                       where e.batch_id = v_exam.batch_id and e.source = 'optic'
                       group by r.subject_id) x));
end;
$$;
revoke execute on function public.exam_card_context(uuid) from public, anon;
grant execute on function public.exam_card_context(uuid) to authenticated;

-- İçe aktarmada numara eşleştirmesi: kurumun bütün öğrencileri (koç da
-- başka koçun öğrencisinin optiğini yükleyebilir).
create or replace function public.exam_import_roster()
returns table (student_id uuid, full_name text, student_number text, classroom_name text)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.full_name, p.student_number, c.name
  from public.profiles p
  left join public.classroom_students cs on cs.student_id = p.id
  left join public.classrooms c on c.id = cs.classroom_id
  where p.role = 'student' and p.org_id = public.my_org()
    and public.is_org_staff(p.org_id)
  order by p.full_name
$$;
revoke all on function public.exam_import_roster() from public, anon;
grant execute on function public.exam_import_roster() to authenticated;
