-- Geri alma: 20261018170000_avatars_more
-- Yeni parçaları kuşanan öğrencilerin avatarından o parçalar çıkarılır
-- (geri kalan seçimleri korunur), parçalar ve açılmaları silinir, kural
-- değerlendirmesi eski haline döner (yeni kural türleri "kilitli" sayılır).

update public.profiles p
set avatar = (
  select coalesce(jsonb_object_agg(k, v), '{}'::jsonb)
  from jsonb_each(p.avatar) as e(k, v)
  where (v #>> '{}')::int < 18
)
where p.avatar is not null
  and exists (
    select 1 from jsonb_each(p.avatar) as e(k, v)
    where (v #>> '{}')::int between 18 and 43
  );

delete from public.avatar_items where id between 18 and 43;

create or replace function public.avatar_rule_met(p_user uuid, p_rule jsonb)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
begin
  return case p_rule ->> 'type'
    when 'free'   then true
    when 'streak' then public.student_best_streak(p_user) >= coalesce((p_rule ->> 'days')::int, 1)
    when 'net'    then public.student_best_net(p_user, p_rule ->> 'exam_type')
                         >= coalesce((p_rule ->> 'value')::numeric, 0)
    when 'badge'  then public.student_has_badge(p_user, p_rule ->> 'badge')
    else false   -- bilinmeyen kural: güvenli tarafta kal
  end;
end;
$$;

revoke execute on function public.avatar_rule_met(uuid, jsonb) from public, anon, authenticated;
