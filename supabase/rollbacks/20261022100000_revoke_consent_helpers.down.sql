-- 20261022100000_revoke_consent_helpers geri alma: eski izinler.
grant execute on function public.is_minor(uuid) to authenticated;
grant execute on function public.has_consent(uuid, text) to authenticated;
grant execute on function public.ranking_visible(uuid) to authenticated;
