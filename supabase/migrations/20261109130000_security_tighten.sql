-- Güvenlik kontrolünün iki düşük bulgusu (NOTLAR §75-76).
--
--  * outcome_label / outcome_topic: DEFINER; UUID bilen her girişli kullanıcıya
--    RLS'i aşarak başka kurumun kazanımını döndürüyordu. Uygulama çağırmıyor,
--    yalnızca save_exam (DEFINER) kullanıyor: doğrudan çağrı kapatıldı.
--  * match_student_number: 'taken' hız sınırına sayılmıyordu; kurum kodunu bilen
--    biri kullanılan numaraları sınırsız deneyebiliyordu. Artık sayılıyor.
--    'ok' bilerek sayılmıyor: okul ağında (tek IP) toplu kayıt engellenmesin.

revoke all on function public.outcome_label(uuid) from public, anon, authenticated;
revoke all on function public.outcome_topic(uuid) from public, anon, authenticated;

create or replace function public.match_student_number(p_code text, p_number text)
returns text
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_headers json := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json;
  v_ip text := coalesce(
    nullif(trim(v_headers ->> 'cf-connecting-ip'), ''),
    nullif(trim(v_headers ->> 'sb-forwarded-for'), ''),
    nullif(trim((regexp_split_to_array(v_headers ->> 'x-forwarded-for', ','))[
      array_length(regexp_split_to_array(v_headers ->> 'x-forwarded-for', ','), 1)]), ''),
    'unknown');
  v_org uuid;
  v_mode text;
  v_number text := regexp_replace(coalesce(p_number, ''), '\s', '', 'g');
  v_row public.expected_students%rowtype;
begin
  if (select count(*) from public.invite_check_failures
      where ip = v_ip and at > now() - interval '10 minutes') >= 30
     or (select count(*) from public.invite_check_failures
         where at > now() - interval '10 minutes') >= 5000 then
    raise exception 'TOO_MANY_ATTEMPTS';
  end if;
  if v_number !~ '^[0-9]{1,20}$' then
    return 'invalid';
  end if;
  v_org := public.org_of_student_code(p_code);
  if v_org is null then
    insert into public.invite_check_failures (ip) values (v_ip);
    return 'not_found';
  end if;
  select student_registration_mode into v_mode from public.organizations where id = v_org;
  if exists (select 1 from public.profiles
             where org_id = v_org and student_number = v_number) then
    insert into public.invite_check_failures (ip) values (v_ip);
    return 'taken';
  end if;
  if v_mode = 'free' then
    return 'ok';
  end if;
  select * into v_row from public.expected_students
  where org_id = v_org and student_number = v_number;
  if not found then
    insert into public.invite_check_failures (ip) values (v_ip);
    return 'not_found';
  end if;
  if v_row.status = 'matched' then
    insert into public.invite_check_failures (ip) values (v_ip);
    return 'taken';
  end if;
  return 'ok';
end;
$$;
revoke all on function public.match_student_number(text, text) from public;
grant execute on function public.match_student_number(text, text) to anon, authenticated;
