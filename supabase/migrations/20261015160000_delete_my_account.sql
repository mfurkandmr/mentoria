-- =====================================================================
-- Hesap silme (App Store / Google Play zorunluluğu)
-- Kullanıcı yalnızca kendi hesabını siler; profil ve bağlı tüm veriler
-- (denemeler, soru kayıtları, görevler...) ON DELETE CASCADE ile silinir.
--  * Kurumun son müdürü silinemez (kurum yöneticisiz kalmasın).
--  * Öğrencisi olan koç silinemez (önce müdür öğrencileri devretmeli).
-- =====================================================================

create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if v_me.role = 'admin' and not exists (
    select 1 from public.profiles
    where org_id = v_me.org_id and role = 'admin' and id <> v_me.id
  ) then
    raise exception 'LAST_ADMIN';
  end if;

  if v_me.role = 'coach' and exists (
    select 1 from public.coach_students where coach_id = v_me.id
  ) then
    raise exception 'COACH_HAS_STUDENTS';
  end if;

  delete from auth.users where id = v_me.id;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant  execute on function public.delete_my_account() to authenticated;
