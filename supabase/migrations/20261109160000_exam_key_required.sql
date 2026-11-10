-- =====================================================================
-- Kurum sınavı anahtar ve kazanım olmadan yayınlanamaz
-- ---------------------------------------------------------------------
-- Öğrenci her sorudaki hatasını ve konusunu görsün diye: iptal edilmemiş her
-- sorunun doğru cevabı ve kazanımı olmalı. Eksikse EXAM_KEY_INCOMPLETE.
-- Daha önce yayınlanmış sınavlar değişmez.
--
-- Geri almak için: supabase/rollbacks/20261109160000_exam_key_required.down.sql
-- =====================================================================

create or replace function public._exam_key_gaps(p_key uuid)
returns int
language sql stable security definer set search_path = ''
as $$
  select count(*)::int
  from public.answer_key_subjects s
  cross join lateral generate_series(1, s.question_count) as n(no)
  left join public.answer_key_items i
    on i.key_id = s.key_id and i.subject_id = s.subject_id and i.question_no = n.no
  where s.key_id = p_key
    and (i.key_id is null
         or (not i.cancelled
             and (i.correct is null
                  or (i.outcome_id is null and nullif(trim(i.outcome), '') is null))))
$$;
revoke all on function public._exam_key_gaps(uuid) from public, anon, authenticated;

create or replace function public.publish_exam(p_key uuid)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_key  public.answer_keys%rowtype;
  v_gaps int;
begin
  v_key := public._key_for_write(p_key);
  if v_key.status = 'published' then
    raise exception 'ALREADY_PUBLISHED';
  end if;
  if not exists (select 1 from public.answer_key_items
                 where key_id = p_key and correct is not null and not cancelled) then
    raise exception 'NO_ITEMS';
  end if;
  v_gaps := public._exam_key_gaps(p_key);
  if v_gaps > 0 then
    raise exception 'EXAM_KEY_INCOMPLETE: % soru eksik', v_gaps;
  end if;
  update public.answer_keys set status = 'published', published_at = now() where id = p_key;
  return public._rescore_key(p_key);
end;
$$;
