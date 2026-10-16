-- =====================================================================
-- White label 2/4: Dershaneye ait her tabloya tenant_id
--
--  * Mevcut kayıtlar doldurulur (profil → kurum → dershane; öğrenci
--    verileri → öğrencinin dershanesi; alt tablolar → üst kaydın dershanesi).
--  * Yeni kayıtlarda tenant_id istemciden ALINMAZ; tetikleyici doldurur.
--    Böylece uygulama kodu değişmeden çalışır ve dershane taklit edilemez.
--  * tenant_id sonradan değiştirilemez (başka dershaneye kayıt taşınamaz).
--  * Pasif dershaneye yeni kullanıcı eklenemez.
--  Referans tablolar (subjects, topics, score_*, rank_tables) ortaktır.
--
-- Geri almak için: supabase/rollbacks/20261017110000_tenant_columns.down.sql
-- =====================================================================

-- 1) Kolonlar
alter table public.profiles             add column tenant_id uuid references public.tenants (id);
alter table public.invite_codes         add column tenant_id uuid references public.tenants (id);
alter table public.coach_students       add column tenant_id uuid references public.tenants (id);
alter table public.parent_students      add column tenant_id uuid references public.tenants (id);
alter table public.exams                add column tenant_id uuid references public.tenants (id);
alter table public.exam_subject_results add column tenant_id uuid references public.tenants (id);
alter table public.exam_wrong_topics    add column tenant_id uuid references public.tenants (id);
alter table public.question_logs        add column tenant_id uuid references public.tenants (id);
alter table public.topic_progress       add column tenant_id uuid references public.tenants (id);
alter table public.study_sessions       add column tenant_id uuid references public.tenants (id);
alter table public.goals                add column tenant_id uuid references public.tenants (id);
alter table public.tasks                add column tenant_id uuid references public.tenants (id);
alter table public.coach_notes          add column tenant_id uuid references public.tenants (id);
alter table public.assignments          add column tenant_id uuid references public.tenants (id);
alter table public.assignment_items     add column tenant_id uuid references public.tenants (id);
alter table public.notifications        add column tenant_id uuid references public.tenants (id);

-- 2) Mevcut kayıtları doldur (sıra önemli: önce profiller)
update public.profiles p set tenant_id = o.tenant_id
  from public.organizations o where o.id = p.org_id;
update public.invite_codes i set tenant_id = o.tenant_id
  from public.organizations o where o.id = i.org_id;

update public.coach_students  x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.parent_students x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.exams           x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.question_logs   x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.topic_progress  x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.study_sessions  x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.goals           x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.tasks           x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.coach_notes     x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.assignments     x set tenant_id = p.tenant_id from public.profiles p where p.id = x.student_id;
update public.notifications   x set tenant_id = p.tenant_id from public.profiles p where p.id = x.user_id;

update public.exam_subject_results x set tenant_id = e.tenant_id from public.exams e where e.id = x.exam_id;
update public.exam_wrong_topics    x set tenant_id = e.tenant_id from public.exams e where e.id = x.exam_id;
update public.assignment_items     x set tenant_id = a.tenant_id from public.assignments a where a.id = x.assignment_id;

-- Kurumu silinmiş (org_id boş) bir öğrenciye ait sahipsiz veri kalırsa
-- NOT NULL adımı hata verir; bu durumda önce o kayıtlar temizlenmelidir.

-- 3) Zorunlu yap (profiller hariç: kurumu silinen kullanıcının dershanesi boş
--    kalabilir; böyle bir kullanıcı RLS ile hiçbir dershane verisini göremez).
alter table public.invite_codes         alter column tenant_id set not null;
alter table public.coach_students       alter column tenant_id set not null;
alter table public.parent_students      alter column tenant_id set not null;
alter table public.exams                alter column tenant_id set not null;
alter table public.exam_subject_results alter column tenant_id set not null;
alter table public.exam_wrong_topics    alter column tenant_id set not null;
alter table public.question_logs        alter column tenant_id set not null;
alter table public.topic_progress       alter column tenant_id set not null;
alter table public.study_sessions       alter column tenant_id set not null;
alter table public.goals                alter column tenant_id set not null;
alter table public.tasks                alter column tenant_id set not null;
alter table public.coach_notes          alter column tenant_id set not null;
alter table public.assignments          alter column tenant_id set not null;
alter table public.assignment_items     alter column tenant_id set not null;
alter table public.notifications        alter column tenant_id set not null;

-- 4) RLS sorguları için indeksler
create index on public.profiles             (tenant_id);
create index on public.invite_codes         (tenant_id);
create index on public.coach_students       (tenant_id);
create index on public.parent_students      (tenant_id);
create index on public.exams                (tenant_id);
create index on public.exam_subject_results (tenant_id);
create index on public.exam_wrong_topics    (tenant_id);
create index on public.question_logs        (tenant_id);
create index on public.topic_progress       (tenant_id);
create index on public.study_sessions       (tenant_id);
create index on public.goals                (tenant_id);
create index on public.tasks                (tenant_id);
create index on public.coach_notes          (tenant_id);
create index on public.assignments          (tenant_id);
create index on public.assignment_items     (tenant_id);
create index on public.notifications        (tenant_id);

-- 5) tenant_id'yi her zaman sunucu belirler
create or replace function public.set_tenant_id()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_tenant uuid;
begin
  -- Güncellemede dershane değişmez. Profil yalnızca aynı dershanedeki
  -- bir kuruma taşınabilir.
  if tg_op = 'UPDATE' then
    if tg_table_name = 'profiles' then
      if new.org_id is distinct from old.org_id and new.org_id is not null then
        select tenant_id into v_tenant from public.organizations where id = new.org_id;
        if old.tenant_id is not null and v_tenant is distinct from old.tenant_id then
          raise exception 'CROSS_TENANT';
        end if;
        new.tenant_id := v_tenant;
        return new;
      end if;
    end if;
    new.tenant_id := old.tenant_id;
    return new;
  end if;

  if tg_table_name in ('profiles', 'invite_codes') then
    select tenant_id into v_tenant from public.organizations where id = new.org_id;
  elsif tg_table_name in ('exam_subject_results', 'exam_wrong_topics') then
    select tenant_id into v_tenant from public.exams where id = new.exam_id;
  elsif tg_table_name = 'assignment_items' then
    select tenant_id into v_tenant from public.assignments where id = new.assignment_id;
  elsif tg_table_name = 'notifications' then
    select tenant_id into v_tenant from public.profiles where id = new.user_id;
  else
    select tenant_id into v_tenant from public.profiles where id = new.student_id;
  end if;

  if tg_table_name = 'profiles' then
    if v_tenant is not null and not exists (
      select 1 from public.tenants where id = v_tenant and is_active
    ) then
      raise exception 'TENANT_INACTIVE';
    end if;
  elsif v_tenant is null then
    raise exception 'TENANT_REQUIRED';
  end if;

  new.tenant_id := v_tenant;
  return new;
end;
$$;
revoke execute on function public.set_tenant_id() from public, anon, authenticated;

create trigger set_tenant_id before insert or update on public.profiles             for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.invite_codes         for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.coach_students       for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.parent_students      for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.exams                for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.exam_subject_results for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.exam_wrong_topics    for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.question_logs        for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.topic_progress       for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.study_sessions       for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.goals                for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.tasks                for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.coach_notes          for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.assignments          for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.assignment_items     for each row execute function public.set_tenant_id();
create trigger set_tenant_id before insert or update on public.notifications        for each row execute function public.set_tenant_id();

-- 6) RLS yardımcıları
create or replace function public.my_tenant()
returns uuid
language sql stable security definer set search_path = ''
as $$ select tenant_id from public.profiles where id = auth.uid() $$;

create or replace function public.my_tenant_active()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce((select t.is_active from public.tenants t
                   where t.id = public.my_tenant()), false)
$$;

revoke execute on function public.my_tenant()        from public, anon;
grant  execute on function public.my_tenant()        to authenticated;
revoke execute on function public.my_tenant_active() from public, anon;
grant  execute on function public.my_tenant_active() to authenticated;
