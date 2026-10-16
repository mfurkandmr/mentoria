-- =====================================================================
-- Deneme yüklemeleri (paketler) ve 7 günlük düzeltme süresi
--
--  * exams.batch_id: bir Excel yüklemesindeki tüm öğrencilerin denemeleri
--    aynı paket kimliğini taşır; elle girilen deneme kendi paketidir.
--    Eski yüklemeler (girenin, adın, türün, alanın, tarihin ve giriş saatinin
--    aynı olduğu satırlar) tek pakete toplanır.
--  * Kural: deneme girildikten sonra 7 gün içinde silinebilir/düzeltilebilir;
--    daha eskilere kimse dokunamaz (RLS + delete_exam_batch).
--  * my_exam_batches: koçun/müdürün kendi yüklediği paketler (son girilen önce).
--  * delete_exam_batch: paketi içindeki tüm öğrencilerden siler; öğrencilere
--    giden "Deneme sonucun geldi" bildirimleri de silinir.
--
-- Geri almak için: supabase/rollbacks/20261017230000_exam_batches.down.sql
-- =====================================================================

alter table public.exams add column batch_id uuid;

-- Eski kayıtlar: dosya yüklemeleri saatlik gruplara, elle girilenler tek tek.
with grouped as (
  select e.id,
         case when e.source = 'import' then
           first_value(e.id) over (
             partition by e.created_by, e.name, e.exam_type, e.field, e.taken_on,
                          date_trunc('hour', e.created_at)
             order by e.created_at, e.id)
         else e.id end as batch
  from public.exams e
)
update public.exams e set batch_id = g.batch
from grouped g where g.id = e.id;

alter table public.exams
  alter column batch_id set default gen_random_uuid(),
  alter column batch_id set not null;
create index on public.exams (created_by, batch_id);

-- Düzeltme süresi: girildikten sonraki 7 gün.
create or replace function public.exam_editable(p_created_at timestamptz)
returns boolean
language sql stable set search_path = ''
as $$ select p_created_at > now() - interval '7 days' $$;

drop policy "coach updates exams" on public.exams;
drop policy "coach deletes exams" on public.exams;
create policy "coach updates exams" on public.exams
  for update to authenticated
  using (public.can_manage_student(student_id) and public.exam_editable(created_at))
  with check (public.can_manage_student(student_id) and public.exam_editable(created_at));
create policy "coach deletes exams" on public.exams
  for delete to authenticated
  using (public.can_manage_student(student_id) and public.exam_editable(created_at));

-- Sonuçlar da yalnızca düzeltme süresindeki denemelerde değişir.
drop policy "coach updates exam results" on public.exam_subject_results;
drop policy "coach deletes exam results" on public.exam_subject_results;
create policy "coach updates exam results" on public.exam_subject_results
  for update to authenticated
  using (exists (select 1 from public.exams e
                 where e.id = exam_id and public.can_manage_student(e.student_id)
                   and public.exam_editable(e.created_at)))
  with check (exists (select 1 from public.exams e
                      where e.id = exam_id and public.can_manage_student(e.student_id)
                        and public.exam_editable(e.created_at)));
create policy "coach deletes exam results" on public.exam_subject_results
  for delete to authenticated
  using (exists (select 1 from public.exams e
                 where e.id = exam_id and public.can_manage_student(e.student_id)
                   and public.exam_editable(e.created_at)));

-- Kendi yüklediğim paketler (sayfalı). RLS'e tabi: yalnızca görebildiğim
-- öğrencilerin satırları sayılır.
create or replace function public.my_exam_batches(p_limit int default 30, p_offset int default 0)
returns table (
  batch_id       uuid,
  name           text,
  exam_type      public.exam_type,
  field          public.field_type,
  publisher      text,
  taken_on       date,
  source         text,
  uploaded_at    timestamptz,
  student_count  int,
  avg_net        numeric,
  editable_until timestamptz,
  editable       boolean
)
language sql stable security invoker set search_path = ''
as $$
  with mine as (
    select e.*,
           (select coalesce(sum(r.net), 0) from public.exam_subject_results r
            where r.exam_id = e.id) as total
    from public.exams e
    where e.created_by = auth.uid()
  )
  select m.batch_id,
         min(m.name), min(m.exam_type::text)::public.exam_type,
         min(m.field::text)::public.field_type, min(m.publisher),
         min(m.taken_on), min(m.source),
         max(m.created_at),
         count(*)::int,
         round(avg(m.total), 2),
         min(m.created_at) + interval '7 days',
         public.exam_editable(min(m.created_at))
  from mine m
  group by m.batch_id
  order by max(m.created_at) desc
  limit least(greatest(p_limit, 1), 100)
  offset greatest(p_offset, 0)
$$;

-- Paketi (kendi yüklediğim) içindeki tüm öğrencilerden siler.
create or replace function public.delete_exam_batch(p_batch uuid)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_ids uuid[];
begin
  if public.my_role() not in ('coach', 'admin') or not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;

  select array_agg(e.id) into v_ids
  from public.exams e
  where e.batch_id = p_batch and e.created_by = auth.uid()
    and e.tenant_id = public.my_tenant();
  if v_ids is null then
    raise exception 'BATCH_NOT_FOUND';
  end if;
  if exists (select 1 from public.exams e
             where e.id = any (v_ids) and not public.exam_editable(e.created_at)) then
    raise exception 'EXAM_LOCKED';
  end if;

  delete from public.notifications n
  where n.kind = 'exam' and n.ref_id = any (v_ids);
  delete from public.exams e where e.id = any (v_ids);
  return coalesce(array_length(v_ids, 1), 0);
end;
$$;

revoke execute on function public.exam_editable(timestamptz)       from public, anon;
grant  execute on function public.exam_editable(timestamptz)       to authenticated;
revoke execute on function public.my_exam_batches(int, int)        from public, anon;
grant  execute on function public.my_exam_batches(int, int)        to authenticated;
revoke execute on function public.delete_exam_batch(uuid)          from public, anon;
grant  execute on function public.delete_exam_batch(uuid)          to authenticated;
