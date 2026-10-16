-- =====================================================================
-- Hesap silme talebi (mağaza uyumu: Apple 5.1.1(v), Google Play)
--
-- Öğrenci kendi hesabını silemez, ama silmeyi uygulama içinden BAŞLATABİLİR:
-- request_account_deletion() bir talep kaydı açar ve öğrencinin koç(lar)ına
-- (koçu yoksa kurum müdür(ler)ine) bildirim düşer. Silme kararı yine koçta:
-- hesabı delete_student_account siler, talep de cascade ile gider.
--  * Öğrencinin aynı anda tek talebi olur (tekrar istek ALREADY_REQUESTED).
--  * Öğrenci talebini geri alabilir (kendi satırını siler).
--  * Geri alıp yeniden isteyerek koçu bildirime boğamaz: aynı öğrenci için
--    son 24 saatte bildirim gittiyse yenisi gönderilmez.
--  * tenant_id istemciden alınmaz (set_tenant_id), RESTRICTIVE izolasyon var.
--
-- Geri almak için: supabase/rollbacks/20261017180000_account_deletion_requests.down.sql
-- =====================================================================

create table public.account_deletion_requests (
  student_id   uuid primary key references public.profiles (id) on delete cascade,
  tenant_id    uuid not null references public.tenants (id),
  requested_at timestamptz not null default now()
);
create index on public.account_deletion_requests (tenant_id);

create trigger set_tenant_id before insert or update on public.account_deletion_requests
  for each row execute function public.set_tenant_id();

alter table public.account_deletion_requests enable row level security;

-- Öğrenci kendi talebini, koçu / kurum müdürü öğrencilerinin taleplerini görür.
create policy "read deletion requests" on public.account_deletion_requests
  for select to authenticated
  using (student_id = (select auth.uid())
         or public.can_manage_student(student_id));
create policy "cancel own deletion request" on public.account_deletion_requests
  for delete to authenticated
  using (student_id = (select auth.uid()));
create policy "tenant isolation" on public.account_deletion_requests as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));

-- Ekleme yalnızca request_account_deletion ile.
revoke insert, update on public.account_deletion_requests from anon, authenticated;
revoke all on public.account_deletion_requests from anon;

-- Yeni bildirim türü: koça "öğrencin hesabının silinmesini istedi".
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('assignment', 'exam', 'task', 'note', 'deletion_request'));

create or replace function public.request_account_deletion()
returns timestamptz
language plpgsql security definer set search_path = ''
as $$
declare
  v_me public.profiles%rowtype;
  v_at timestamptz;
  v_n  int;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if not found then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if v_me.role <> 'student' then
    raise exception 'NOT_A_STUDENT';
  end if;

  insert into public.account_deletion_requests (student_id)
  values (v_me.id)
  on conflict (student_id) do nothing
  returning requested_at into v_at;
  if v_at is null then
    raise exception 'ALREADY_REQUESTED';
  end if;

  -- Geri al / yeniden iste döngüsüyle bildirim yağdırılmasın.
  if exists (
    select 1 from public.notifications
    where kind = 'deletion_request' and ref_id = v_me.id
      and created_at > now() - interval '24 hours'
  ) then
    return v_at;
  end if;

  insert into public.notifications (user_id, kind, data, ref_id)
  select cs.coach_id, 'deletion_request',
         jsonb_build_object('student', v_me.full_name,
                            'route', '/coach/students/' || v_me.id),
         v_me.id
  from public.coach_students cs
  where cs.student_id = v_me.id;
  get diagnostics v_n = row_count;

  -- Koçu yoksa talep kurum müdür(ler)ine gider.
  if v_n = 0 then
    insert into public.notifications (user_id, kind, data, ref_id)
    select p.id, 'deletion_request',
           jsonb_build_object('student', v_me.full_name,
                              'route', '/admin/students/' || v_me.id),
           v_me.id
    from public.profiles p
    where p.org_id = v_me.org_id and p.role = 'admin';
  end if;

  return v_at;
end;
$$;
revoke execute on function public.request_account_deletion() from public, anon;
grant  execute on function public.request_account_deletion() to authenticated;
