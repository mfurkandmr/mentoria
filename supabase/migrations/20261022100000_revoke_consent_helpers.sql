-- KVKK yardımcıları doğrudan çağrılamasın.
--
-- is_minor, has_consent ve ranking_visible çağıranın kim olduğuna bakmıyordu:
-- giriş yapan herkes UUID'sini bildiği birinin 18 yaş altı olup olmadığını ve
-- rızalarını /rest/v1/rpc üzerinden öğrenebiliyordu. Bu fonksiyonlar yalnızca
-- başka SECURITY DEFINER fonksiyonların içinden (consent_status, set_consent,
-- success_scores, avatar_leaderboard, create_invite, check_invite) çağrılıyor;
-- onlar sahibin (postgres) yetkisiyle çalıştığı için çalışmaya devam eder.
-- Hiçbir RLS politikası bu fonksiyonları kullanmıyor.

revoke all on function public.is_minor(uuid) from public, anon, authenticated;
revoke all on function public.has_consent(uuid, text) from public, anon, authenticated;
revoke all on function public.ranking_visible(uuid) from public, anon, authenticated;
