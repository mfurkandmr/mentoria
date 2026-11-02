-- =====================================================================
-- Öğrencinin kendi çalışma programı
-- ---------------------------------------------------------------------
--  * plan_items.start_time: maddenin başlangıç saati (isteğe bağlı). Süre
--    (minutes) ile birlikte "09:00–09:45" gibi bir zaman dilimi olur.
--  * Öğrenci kendi haftasına madde ekler ve yalnızca kendi eklediği
--    maddeleri siler; koçun / müdürün maddelerini yine yalnızca işaretler.
--    Günde en çok 12 madde ve geçmiş hafta sınırı herkes için aynı.
--  * Öğrencinin kendi eklediği maddeler bildirim üretmez (notify_plan_item
--    zaten created_by = student_id olanları atlıyor).
--
-- Geri almak için: supabase/rollbacks/20261031100000_student_self_plan.down.sql
-- =====================================================================

alter table public.plan_items add column start_time time;

create or replace function public.guard_plan_item()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if (select role from public.profiles where id = new.student_id) <> 'student' then
      raise exception 'PLAN_NOT_STUDENT';
    end if;
    new.created_by := auth.uid();
    new.created_at := now();
    new.done_at := null;
    -- Dakika altı hassasiyet gereksiz: 09:00:37 → 09:00.
    new.start_time := date_trunc('minute', new.start_time);
    if new.day < (now() at time zone 'Europe/Istanbul')::date - 7 then
      raise exception 'PLAN_DAY_PAST';
    end if;
    if (select count(*) from public.plan_items
        where student_id = new.student_id and day = new.day) >= 12 then
      raise exception 'PLAN_DAY_FULL';
    end if;
  else
    -- Yalnızca "yaptım" işareti değişebilir; zaman sunucudan.
    if (new.student_id, new.day, new.subject_code, new.topic, new.question_count,
        new.minutes, new.note, new.created_by, new.created_at, new.tenant_id,
        new.start_time)
       is distinct from
       (old.student_id, old.day, old.subject_code, old.topic, old.question_count,
        old.minutes, old.note, old.created_by, old.created_at, old.tenant_id,
        old.start_time) then
      raise exception 'PLAN_READ_ONLY';
    end if;
    new.done_at := case when new.done_at is null then null else coalesce(old.done_at, now()) end;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_plan_item() from public, anon, authenticated;

create policy "student adds own plan" on public.plan_items
  for insert to authenticated
  with check (student_id = (select auth.uid()));
create policy "student deletes own items" on public.plan_items
  for delete to authenticated
  using (student_id = (select auth.uid()) and created_by = (select auth.uid()));
