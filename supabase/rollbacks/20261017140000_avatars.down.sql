-- Geri alma: 20261017140000_avatars
drop function if exists public.avatar_leaderboard(int, int);
drop trigger if exists guard_avatar on public.profiles;
drop function if exists public.guard_avatar();
drop function if exists public.claim_avatar_unlocks();
drop function if exists public.avatar_rule_met(uuid, jsonb);
drop function if exists public.student_has_badge(uuid, text);
drop function if exists public.student_best_net(uuid, text);
drop function if exists public.student_best_streak(uuid);

revoke update (avatar) on public.profiles from authenticated;
alter table public.profiles drop column if exists avatar;

drop table if exists public.user_unlocked_items;
drop table if exists public.avatar_items;
