-- 20261109160000_exam_key_required geri alma: yayın kontrolü eski haline döner.

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

drop function if exists public._exam_key_gaps(uuid);
