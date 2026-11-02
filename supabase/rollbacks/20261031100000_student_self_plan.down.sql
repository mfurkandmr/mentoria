-- Geri alma: 20261031100000_student_self_plan
-- Öğrencinin eklediği maddeler kalır (koç görür, silebilir); yalnızca saat
-- bilgisi ve öğrencinin ekleme / silme yetkisi kalkar. guard_plan_item
-- 20261018240000_plan_and_trends sürümüne döner (aşağıdaki oradan aynen kopya).
drop policy if exists "student adds own plan" on public.plan_items;
drop policy if exists "student deletes own items" on public.plan_items;

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
        new.minutes, new.note, new.created_by, new.created_at, new.tenant_id)
       is distinct from
       (old.student_id, old.day, old.subject_code, old.topic, old.question_count,
        old.minutes, old.note, old.created_by, old.created_at, old.tenant_id) then
      raise exception 'PLAN_READ_ONLY';
    end if;
    new.done_at := case when new.done_at is null then null else coalesce(old.done_at, now()) end;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_plan_item() from public, anon, authenticated;

alter table public.plan_items drop column if exists start_time;
