-- =====================================================================
-- Avatar: daha çok parça ve başarımla açılan yeni ödüller
-- ---------------------------------------------------------------------
-- 26 yeni parça (17 → 43): 2 ten, 9 saç (başörtüsü dahil), 6 kıyafet,
-- 9 aksesuar. Yeni açılma kuralları (sayılar kural verisinde, uygulamada
-- değil):
--   {"type": "questions",     "count": 500}    toplam çözülen soru
--   {"type": "study_minutes", "minutes": 3000} toplam odaklanma süresi
--   {"type": "topics",        "count": 25}     bitirilen konu
--   {"type": "exams",         "count": 5}      girilen deneme
-- Mevcut kurallar (free, streak, net, badge) aynen geçerli.
--
-- Geri almak için: supabase/rollbacks/20261018170000_avatars_more.down.sql
-- =====================================================================

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
    when 'questions' then (
      select coalesce(sum(correct + wrong + blank), 0)
      from public.question_logs where student_id = p_user
    ) >= coalesce((p_rule ->> 'count')::int, 1)
    when 'study_minutes' then (
      select coalesce(sum(duration_sec), 0) / 60
      from public.study_sessions where student_id = p_user
    ) >= coalesce((p_rule ->> 'minutes')::int, 1)
    when 'topics' then (
      select count(*) from public.topic_progress
      where student_id = p_user and status = 'done'
    ) >= coalesce((p_rule ->> 'count')::int, 1)
    when 'exams' then (
      select count(*) from public.exams where student_id = p_user
    ) >= coalesce((p_rule ->> 'count')::int, 1)
    else false   -- bilinmeyen kural: güvenli tarafta kal
  end;
end;
$$;

revoke execute on function public.avatar_rule_met(uuid, jsonb) from public, anon, authenticated;

insert into public.avatar_items (id, category, asset_name, unlock_rule, sort) values
  -- Ten (herkese açık)
  (18, 'skin',      'skin_fair',        '{"type": "free"}', 5),
  (19, 'skin',      'skin_olive',       '{"type": "free"}', 6),
  -- Saç
  (20, 'hair',      'hair_long',        '{"type": "free"}', 6),
  (21, 'hair',      'hair_ponytail',    '{"type": "free"}', 7),
  (22, 'hair',      'hair_hijab',       '{"type": "free"}', 8),
  (23, 'hair',      'hair_afro',        '{"type": "free"}', 9),
  (24, 'hair',      'hair_wavy',        '{"type": "free"}', 10),
  (25, 'hair',      'hair_braids',      '{"type": "questions", "count": 500}', 11),
  (26, 'hair',      'hair_mohawk',      '{"type": "streak", "days": 14}', 12),
  (27, 'hair',      'hair_galaxy',      '{"type": "net", "exam_type": "AYT", "value": 50}', 13),
  (28, 'hair',      'hair_golden',      '{"type": "badge", "badge": "question_machine"}', 14),
  -- Kıyafet
  (29, 'outfit',    'outfit_uniform',   '{"type": "free"}', 6),
  (30, 'outfit',    'outfit_sweater',   '{"type": "free"}', 7),
  (31, 'outfit',    'outfit_labcoat',   '{"type": "topics", "count": 25}', 8),
  (32, 'outfit',    'outfit_jersey',    '{"type": "exams", "count": 5}', 9),
  (33, 'outfit',    'outfit_astronaut', '{"type": "study_minutes", "minutes": 3000}', 10),
  (34, 'outfit',    'outfit_graduate',  '{"type": "exams", "count": 20}', 11),
  -- Aksesuar
  (35, 'accessory', 'acc_cap',          '{"type": "free"}', 4),
  (36, 'accessory', 'acc_beanie',       '{"type": "free"}', 5),
  (37, 'accessory', 'acc_flower',       '{"type": "free"}', 6),
  (38, 'accessory', 'acc_bow',          '{"type": "free"}', 7),
  (39, 'accessory', 'acc_pencil',       '{"type": "questions", "count": 250}', 8),
  (40, 'accessory', 'acc_sunglasses',   '{"type": "streak", "days": 5}', 9),
  (41, 'accessory', 'acc_bee_antenna',  '{"type": "questions", "count": 2000}', 10),
  (42, 'accessory', 'acc_grad_cap',     '{"type": "exams", "count": 10}', 11),
  (43, 'accessory', 'acc_halo',         '{"type": "study_minutes", "minutes": 6000}', 12);
