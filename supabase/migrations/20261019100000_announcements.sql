-- =====================================================================
-- Toplu duyuru
-- ---------------------------------------------------------------------
-- Kurum müdürü kurumun tamamına, öğrencilere, velilere ya da koçlara; koç
-- kendi öğrencilerine ya da onların velilerine tek seferde duyuru gönderir.
--
--  * announcements: gönderilen duyurular (başlık, metin, hedef kitle, alıcı
--    sayısı). İstemci doğrudan yazamaz; yalnızca send_announcement().
--  * Her alıcıya 'announcement' bildirimi düşer (ref_id = duyuru); telefon
--    bildirimi mevcut push tetikleyicisiyle gider.
--  * my_announcements(): bana gelen ve benim gönderdiğim duyurular. Gelenler
--    bildirim satırları üzerinden bulunur, yani yalnızca gerçekten alıcı
--    olanlar görür.
--  * Kötüye kullanıma karşı: gönderen başına 24 saatte en fazla 10 duyuru.
--
-- Geri almak için: supabase/rollbacks/20261019100000_announcements.down.sql
-- =====================================================================

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request',
                  'meeting', 'review', 'weekly_report', 'daily_question',
                  'duel', 'duel_result', 'plan', 'announcement'));

create table public.announcements (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references public.tenants (id),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  sender_id  uuid references public.profiles (id) on delete set null,
  audience   text not null check (audience in
               ('everyone', 'students', 'parents', 'coaches', 'my_students', 'my_parents')),
  title      text not null check (length(title) between 2 and 80),
  body       text not null check (length(body) between 1 and 600),
  recipients int  not null default 0,
  created_at timestamptz not null default now()
);
create index on public.announcements (org_id, created_at desc);
create index on public.announcements (sender_id, created_at desc);
create index on public.announcements (tenant_id);

alter table public.announcements enable row level security;
-- Gönderen kendi duyurularını, kurum müdürü kurumdakilerin hepsini görür.
create policy "sender or org admin reads" on public.announcements
  for select to authenticated
  using (sender_id = (select auth.uid())
         or ((select public.my_role()) = 'admin' and org_id = (select public.my_org())));
create policy "tenant isolation" on public.announcements as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));
revoke all on public.announcements from anon;
revoke insert, update, delete, truncate, trigger, references
  on public.announcements from authenticated;

-- Duyuru gönderir; alıcı sayısını döner.
create or replace function public.send_announcement(
  p_audience text, p_title text, p_body text)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  v_me     public.profiles;
  v_title  text := trim(coalesce(p_title, ''));
  v_body   text := trim(coalesce(p_body, ''));
  v_id     uuid;
  v_to     uuid[];
  v_count  int;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or v_me.org_id is null then
    raise exception 'NOT_ALLOWED';
  end if;
  if not public.my_tenant_active() then
    raise exception 'NOT_ALLOWED';
  end if;
  if not ((v_me.role = 'admin' and p_audience in ('everyone', 'students', 'parents', 'coaches'))
       or (v_me.role = 'coach' and p_audience in ('my_students', 'my_parents'))) then
    raise exception 'NOT_ALLOWED';
  end if;
  if length(v_title) < 2 or length(v_title) > 80
     or length(v_body) < 1 or length(v_body) > 600 then
    raise exception 'ANNOUNCE_INVALID';
  end if;
  if (select count(*) from public.announcements
      where sender_id = v_me.id and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'ANNOUNCE_LIMIT';
  end if;

  select coalesce(array_agg(distinct r.uid), '{}') into v_to from (
    select id as uid from public.profiles
    where org_id = v_me.org_id and role = 'student'
      and p_audience in ('everyone', 'students')
    union all
    select id from public.profiles
    where org_id = v_me.org_id and role = 'coach'
      and p_audience in ('everyone', 'coaches')
    union all
    select ps.parent_id from public.parent_students ps
    join public.profiles s on s.id = ps.student_id
    join public.profiles p on p.id = ps.parent_id
    where s.org_id = v_me.org_id and p.tenant_id = v_me.tenant_id
      and p_audience in ('everyone', 'parents')
    union all
    select cs.student_id from public.coach_students cs
    where cs.coach_id = v_me.id and p_audience = 'my_students'
    union all
    select ps.parent_id from public.coach_students cs
    join public.parent_students ps on ps.student_id = cs.student_id
    join public.profiles p on p.id = ps.parent_id
    where cs.coach_id = v_me.id and p.tenant_id = v_me.tenant_id
      and p_audience = 'my_parents'
  ) r where r.uid <> v_me.id;

  v_count := cardinality(v_to);
  if v_count = 0 then
    raise exception 'ANNOUNCE_NO_RECIPIENTS';
  end if;

  insert into public.announcements (tenant_id, org_id, sender_id, audience, title, body, recipients)
  values (v_me.tenant_id, v_me.org_id, v_me.id, p_audience, v_title, v_body, v_count)
  returning id into v_id;

  insert into public.notifications (user_id, kind, data, ref_id)
  select t.user_id, 'announcement',
         jsonb_build_object(
           'title', v_title,
           'body', v_body,
           'from', v_me.full_name,
           'route', case p.role when 'student' then '/student/announcements'
                                when 'parent'  then '/parent/announcements'
                                when 'coach'   then '/coach/announcements'
                                else '/admin/announcements' end),
         v_id
  from unnest(v_to) as t(user_id) join public.profiles p on p.id = t.user_id;

  return v_count;
end;
$$;
revoke all on function public.send_announcement(text, text, text) from public, anon;
grant execute on function public.send_announcement(text, text, text) to authenticated;

-- Bana gelenler ve benim gönderdiklerim (müdür: kurumdaki tüm gönderilenler),
-- yeniden eskiye, en fazla 100.
create or replace function public.my_announcements()
returns table (
  id uuid, title text, body text, audience text, sender_name text,
  sent_by_me boolean, recipients int, created_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  with mine as (
    select a.id from public.announcements a
    join public.notifications n on n.ref_id = a.id and n.kind = 'announcement'
    where n.user_id = auth.uid()
    union
    select a.id from public.announcements a
    where a.sender_id = auth.uid()
       or (public.my_role() = 'admin' and a.org_id = public.my_org())
  )
  select a.id, a.title, a.body, a.audience, s.full_name,
         a.sender_id = auth.uid(),
         -- Alıcı sayısı yalnızca gönderene ve müdüre.
         case when a.sender_id = auth.uid()
                or (public.my_role() = 'admin' and a.org_id = public.my_org())
              then a.recipients end,
         a.created_at
  from mine m
  join public.announcements a on a.id = m.id
  left join public.profiles s on s.id = a.sender_id
  where a.tenant_id = public.my_tenant()
  order by a.created_at desc
  limit 100
$$;
revoke all on function public.my_announcements() from public, anon;
grant execute on function public.my_announcements() to authenticated;
