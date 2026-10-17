-- =====================================================================
-- Haftalık plan bildirimi
-- ---------------------------------------------------------------------
-- Koç ya da müdür bir haftaya madde eklediğinde öğrenciye 'plan' bildirimi
-- gider. Madde madde yağmasın diye aynı hafta için 30 dakikada bir kez
-- gönderilir ("Geçen haftayı kopyala" da tek bildirim üretir). Geçmiş
-- haftalar için bildirim yok.
--
-- Geri almak için: supabase/rollbacks/20261018250000_plan_notifications.down.sql
-- =====================================================================

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan'));

create or replace function public.notify_plan_item()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_week  date := new.day - (extract(isodow from new.day)::int - 1);
begin
  if new.created_by is null or new.created_by = new.student_id then
    return null;
  end if;
  if v_week < v_today - (extract(isodow from v_today)::int - 1) then
    return null;  -- geçmiş hafta
  end if;
  if exists (select 1 from public.notifications n
             where n.user_id = new.student_id and n.kind = 'plan'
               and n.data ->> 'week' = v_week::text
               and n.created_at > now() - interval '30 minutes') then
    return null;
  end if;
  insert into public.notifications (user_id, kind, data)
  values (new.student_id, 'plan', jsonb_build_object(
    'week', v_week::text,
    'from', (select full_name from public.profiles where id = new.created_by),
    'route', '/student/plan'));
  return null;
end;
$$;
revoke all on function public.notify_plan_item() from public, anon, authenticated;

create trigger notify_plan_item after insert on public.plan_items
  for each row execute function public.notify_plan_item();
