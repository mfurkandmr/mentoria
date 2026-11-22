-- =====================================================================
-- Toplu ödev: aynı ödev birden çok öğrenciye (NOTLAR §104)
-- ---------------------------------------------------------------------
-- send_assignment_bulk(öğrenciler[], başlık, maddeler, son tarih, not):
--  * her öğrenci için ayrı ödev kaydı (send_assignment'ı çağırır; öğrenci
--    başına yetki, madde ve bildirim kuralları aynen geçerli),
--  * hepsi ya da hiçbiri: biri reddedilirse tüm işlem geri alınır,
--  * tek çağrıda en çok 30 öğrenci; gönderen başına 24 saatte en çok 300
--    ödev kaydı (bildirim sıkıştırmasına karşı),
--  * ödev kimlikleri öğrenci sırasıyla döner (istemci veliye PDF'i bu
--    kimliklerle ayrı ayrı gönderir).
--
-- Geri almak için: supabase/rollbacks/20261121100000_assignment_bulk.down.sql
-- =====================================================================

create or replace function public.send_assignment_bulk(
  p_students uuid[],
  p_title    text,
  p_items    jsonb,
  p_due_on   date default null,
  p_note     text default null)
returns uuid[]
language plpgsql security definer set search_path = ''
as $$
declare
  v_students uuid[];
  v_ids      uuid[] := '{}';
  v_one      uuid;
  v_s        uuid;
begin
  -- Yinelenenleri at, sırayı koru.
  select coalesce(array_agg(x.sid order by x.ord), '{}') into v_students
  from (select t.sid, min(t.ord) ord
        from unnest(coalesce(p_students, '{}')) with ordinality as t(sid, ord)
        where t.sid is not null
        group by t.sid) x;

  if coalesce(cardinality(v_students), 0) = 0 then
    raise exception 'NO_STUDENTS';
  end if;
  if cardinality(v_students) > 30 then
    raise exception 'TOO_MANY_STUDENTS';
  end if;
  if (select count(*) from public.assignments
      where coach_id = auth.uid() and created_at > now() - interval '24 hours')
     + cardinality(v_students) > 300 then
    raise exception 'ASSIGNMENT_DAILY_LIMIT';
  end if;

  foreach v_s in array v_students loop
    v_one := public.send_assignment(v_s, p_title, p_items, p_due_on, p_note);
    v_ids := v_ids || v_one;
  end loop;
  return v_ids;
end;
$$;
revoke execute on function public.send_assignment_bulk(uuid[], text, jsonb, date, text) from public, anon;
grant  execute on function public.send_assignment_bulk(uuid[], text, jsonb, date, text) to authenticated;
