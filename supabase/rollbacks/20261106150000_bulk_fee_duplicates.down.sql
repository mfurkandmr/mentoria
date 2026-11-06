-- 20261106150000_bulk_fee_duplicates geri alma: eski imza (atlama zorunlu).
drop function if exists public.create_fees_bulk(uuid[], text, numeric, jsonb, jsonb, text, int, boolean);

create or replace function public.create_fees_bulk(
  p_students uuid[], p_title text, p_total numeric, p_discounts jsonb,
  p_installments jsonb, p_note text, p_due_day int)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_org     uuid := (select org_id from public.profiles where id = auth.uid() and role = 'admin');
  s         uuid;
  v_created int := 0;
  v_skipped uuid[] := '{}';
  g         record;
begin
  if v_org is null then
    raise exception 'FINANCE_NOT_ADMIN';
  end if;
  if coalesce(cardinality(p_students), 0) not between 1 and 500 then
    raise exception 'FINANCE_BAD_STUDENTS';
  end if;
  foreach s in array p_students loop
    if not exists (select 1 from public.profiles
                   where id = s and role = 'student' and org_id = v_org)
       or exists (select 1 from public.finance_fees
                  where student_id = s and status = 'active'
                    and public.norm_key(title) = public.norm_key(p_title)) then
      v_skipped := v_skipped || s;
      continue;
    end if;
    select guardian_name, phone into g from public.student_guardian_phones where student_id = s;
    perform public.create_fee(s, p_title, p_total, p_discounts, p_installments, p_note,
                              p_due_day, g.guardian_name, g.phone);
    v_created := v_created + 1;
  end loop;
  return jsonb_build_object('created', v_created, 'skipped', to_jsonb(v_skipped));
end;
$$;
revoke all on function public.create_fees_bulk(uuid[], text, numeric, jsonb, jsonb, text, int) from public, anon;
grant execute on function public.create_fees_bulk(uuid[], text, numeric, jsonb, jsonb, text, int) to authenticated;
