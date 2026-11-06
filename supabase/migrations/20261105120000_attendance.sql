-- =====================================================================
-- Günlük yoklama ve "öğrenci gelmedi" SMS'i
-- ---------------------------------------------------------------------
--  * attendance: öğrenci başına günde bir satır (geldi / gelmedi / geç
--    geldi / izinli). Koç kendi öğrencilerini, müdür kurumun bütün
--    öğrencilerini işaretler (my_managed_students). Yazma yalnızca
--    save_attendance ile; son 30 gün değiştirilebilir, ileri tarih yok.
--    Öğrenci ve veli görmez. 1 yıldan eski kayıtlar her gece silinir.
--  * student_guardian_phones: yoklama SMS'inin gideceği veli adı ve cep
--    telefonu (+905XXXXXXXXX). Koç ya da müdür set_guardian_phone ile
--    yazar; öğrencinin koçu ve müdür görür.
--  * attendance_day(gün): yönettiğim öğrenciler + o günün durumu + veli
--    telefonu var mı. Telefon bu tabloda yoksa, kurum finansındaki
--    ödeyen veli telefonu (finance_fees.payer_phone) da sayılır; o numara
--    koça gösterilmez, yalnızca SMS'te kullanılır.
--  * send_absence_sms(gün, öğrenciler): "gelmedi" işaretli ve telefonu
--    olanlar için sms_outbox'a mesaj yazar; aynı öğrenciye aynı gün bir
--    kez. SMS sağlayıcısı bağlanana kadar mesajlar sırada bekler
--    (20261105110000_finance_reminders, send-sms).
--
-- Geri almak için: supabase/rollbacks/20261105120000_attendance.down.sql
-- =====================================================================

create table public.attendance (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references public.tenants (id),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  day        date not null,
  status     text not null check (status in ('present', 'absent', 'late', 'excused')),
  marked_by  uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now(),
  sms_at     timestamptz,
  unique (student_id, day)
);
create index on public.attendance (org_id, day);
create index on public.attendance (tenant_id);
create index on public.attendance (marked_by);

alter table public.attendance enable row level security;
create policy "manager reads attendance" on public.attendance
  for select to authenticated
  using ((select public.can_manage_student(student_id)));
create policy "tenant isolation" on public.attendance as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));
revoke all on public.attendance from anon;
revoke insert, update, delete, truncate, trigger, references
  on public.attendance from authenticated;

create table public.student_guardian_phones (
  student_id    uuid primary key references public.profiles (id) on delete cascade,
  tenant_id     uuid not null references public.tenants (id),
  guardian_name text check (length(guardian_name) <= 80),
  phone         text not null check (phone ~ '^\+905[0-9]{9}$'),
  updated_by    uuid references public.profiles (id) on delete set null,
  updated_at    timestamptz not null default now()
);
create index on public.student_guardian_phones (tenant_id);
create index on public.student_guardian_phones (updated_by);

alter table public.student_guardian_phones enable row level security;
create policy "manager reads guardian phone" on public.student_guardian_phones
  for select to authenticated
  using ((select public.can_manage_student(student_id)));
create policy "tenant isolation" on public.student_guardian_phones as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));
revoke all on public.student_guardian_phones from anon;
revoke insert, update, delete, truncate, trigger, references
  on public.student_guardian_phones from authenticated;

alter table public.sms_outbox
  add column attendance_id uuid references public.attendance (id) on delete set null;
create index on public.sms_outbox (attendance_id);

-- Bu öğrenciyi ben (koç ya da müdür) yönetiyor muyum ve öğrenci mi?
create or replace function public.can_mark_attendance(p_student uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.my_managed_students() m(id)
    join public.profiles p on p.id = m.id
    where m.id = p_student and p.role = 'student' and p.org_id is not null)
$$;
revoke all on function public.can_mark_attendance(uuid) from public, anon, authenticated;

-- Veli telefonu: SMS'te önce bu tablo, yoksa finanstaki ödeyen veli.
create or replace function public.guardian_phone_of(p_student uuid)
returns table (guardian_name text, phone text)
language sql stable security definer set search_path = ''
as $$
  select x.guardian_name, x.phone
  from (
    select 0 prio, g.guardian_name, g.phone, g.updated_at ts
    from public.student_guardian_phones g
    where g.student_id = p_student
    union all
    select 1, f.payer_name, f.payer_phone, f.created_at
    from public.finance_fees f
    where f.student_id = p_student and f.payer_phone is not null) x
  order by x.prio, x.ts desc
  limit 1
$$;
revoke all on function public.guardian_phone_of(uuid) from public, anon, authenticated;

create or replace function public.attendance_day(p_day date)
returns table (
  student_id     uuid,
  full_name      text,
  student_number text,
  status         text,
  sms_at         timestamptz,
  has_phone      boolean,
  guardian_name  text,
  guardian_phone text
)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.full_name, p.student_number, a.status, a.sms_at,
         (g.phone is not null or exists (
            select 1 from public.finance_fees f
            where f.student_id = p.id and f.payer_phone is not null)),
         g.guardian_name, g.phone
  from public.my_managed_students() m(id)
  join public.profiles p on p.id = m.id and p.role = 'student' and p.org_id is not null
  left join public.attendance a on a.student_id = p.id and a.day = p_day
  left join public.student_guardian_phones g on g.student_id = p.id
  order by p.full_name
$$;
revoke all on function public.attendance_day(date) from public, anon;
grant execute on function public.attendance_day(date) to authenticated;

-- p_marks: {"<öğrenci id>": "present" | "absent" | "late" | "excused" | null}
-- (null = işareti kaldır). Döner: değişen satır sayısı.
create or replace function public.save_attendance(p_day date, p_marks jsonb)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  r record;
  v_n int := 0;
begin
  if p_day is null or p_day > v_today or p_day < v_today - 30 then
    raise exception 'ATTENDANCE_BAD_DATE';
  end if;
  if jsonb_typeof(p_marks) <> 'object' then
    raise exception 'ATTENDANCE_BAD_INPUT';
  end if;
  if (select count(*) from jsonb_object_keys(p_marks)) > 1000 then
    raise exception 'TOO_MANY';
  end if;
  for r in select key::uuid sid, value from jsonb_each(p_marks) loop
    if not public.can_mark_attendance(r.sid) then
      raise exception 'ATTENDANCE_NOT_MANAGER';
    end if;
    if r.value is null or r.value = 'null'::jsonb then
      delete from public.attendance where student_id = r.sid and day = p_day;
    elsif r.value #>> '{}' in ('present', 'absent', 'late', 'excused') then
      insert into public.attendance (tenant_id, org_id, student_id, day, status, marked_by)
      select p.tenant_id, p.org_id, p.id, p_day, r.value #>> '{}', auth.uid()
      from public.profiles p where p.id = r.sid
      on conflict (student_id, day) do update
        set status = excluded.status, marked_by = excluded.marked_by,
            updated_at = now()
        where public.attendance.status is distinct from excluded.status;
    else
      raise exception 'ATTENDANCE_BAD_INPUT';
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;
revoke all on function public.save_attendance(date, jsonb) from public, anon;
grant execute on function public.save_attendance(date, jsonb) to authenticated;

-- p_phone null ya da boş: kayıtlı numara silinir.
create or replace function public.set_guardian_phone(
  p_student uuid, p_name text, p_phone text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.can_mark_attendance(p_student) then
    raise exception 'ATTENDANCE_NOT_MANAGER';
  end if;
  if nullif(trim(p_phone), '') is null then
    delete from public.student_guardian_phones where student_id = p_student;
    return;
  end if;
  if p_phone !~ '^\+905[0-9]{9}$' then
    raise exception 'BAD_PHONE';
  end if;
  insert into public.student_guardian_phones
    (student_id, tenant_id, guardian_name, phone, updated_by)
  select p.id, p.tenant_id, left(nullif(trim(p_name), ''), 80), p_phone, auth.uid()
  from public.profiles p where p.id = p_student
  on conflict (student_id) do update
    set guardian_name = excluded.guardian_name, phone = excluded.phone,
        updated_by = excluded.updated_by, updated_at = now();
end;
$$;
revoke all on function public.set_guardian_phone(uuid, text, text) from public, anon;
grant execute on function public.set_guardian_phone(uuid, text, text) to authenticated;

-- "Gelmedi" işaretli öğrencilerin velisine SMS (sıraya yazar).
create or replace function public.send_absence_sms(p_day date, p_students uuid[])
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  v_phone text;
  v_name text;
  v_queued int := 0;
  v_no_phone int := 0;
  v_skipped int := 0;
begin
  if coalesce(cardinality(p_students), 0) > 1000 then
    raise exception 'TOO_MANY';
  end if;
  for r in
    select s.sid, a.id att_id, a.status, a.sms_at, a.org_id, a.tenant_id,
           p.full_name, o.name org_name
    from unnest(p_students) s(sid)
    left join public.attendance a on a.student_id = s.sid and a.day = p_day
    left join public.profiles p on p.id = s.sid
    left join public.organizations o on o.id = a.org_id
  loop
    if not public.can_mark_attendance(r.sid) then
      raise exception 'ATTENDANCE_NOT_MANAGER';
    end if;
    if r.att_id is null or r.status <> 'absent' or r.sms_at is not null then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    select g.guardian_name, g.phone into v_name, v_phone
    from public.guardian_phone_of(r.sid) g;
    if v_phone is null then
      v_no_phone := v_no_phone + 1;
      continue;
    end if;
    insert into public.sms_outbox
      (tenant_id, org_id, attendance_id, phone, body, created_by)
    values (
      r.tenant_id, r.org_id, r.att_id, v_phone,
      format('Sayın %s, %s: öğrenciniz %s %s tarihinde kuruma gelmedi. Bilgilerinize.',
             coalesce(nullif(trim(v_name), ''), 'Veli'), r.org_name, r.full_name,
             to_char(p_day, 'DD.MM.YYYY')),
      auth.uid());
    update public.attendance set sms_at = now() where id = r.att_id;
    v_queued := v_queued + 1;
  end loop;
  if v_queued > 0 then
    perform public.kick_sms();
  end if;
  return jsonb_build_object('queued', v_queued, 'no_phone', v_no_phone,
                            'skipped', v_skipped);
end;
$$;
revoke all on function public.send_absence_sms(date, uuid[]) from public, anon;
grant execute on function public.send_absence_sms(date, uuid[]) to authenticated;

-- KVKK: 1 yıldan eski yoklama kayıtları silinir.
create or replace function public.purge_old_attendance(p_now timestamptz default now())
returns integer
language sql security definer set search_path = ''
as $$
  with d as (
    delete from public.attendance
    where day < ((p_now at time zone 'Europe/Istanbul')::date - interval '1 year')
    returning 1)
  select count(*)::int from d
$$;
revoke all on function public.purge_old_attendance(timestamptz) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('attendance-retention', '40 0 * * *',
                          'select public.purge_old_attendance()');
  else
    raise notice 'pg_cron yok (yerel test ortamı); zamanlanmadı';
  end if;
end;
$$;
