-- =====================================================================
-- Rehberlik görüşme kaydı
-- ---------------------------------------------------------------------
-- Öğretmen 2 dakikada not bırakır; öğrencinin görüşme geçmişi zaman
-- çizelgesi olarak durur. Öğretmen ayrılsa da kayıt kurumda kalır.
--  * guidance_logs: görüşme tarihi, türü (yüz yüze / telefon / online /
--    veli), konular (sabit etiketler), not, sonraki adım, takip tarihi.
--  * Yazan: koç ya da müdür (can_manage_student). author_id ve author_name
--    sunucuda yazılır; yazan silinse (on delete set null) adı kayıtta kalır.
--  * Kim görür: öğrencinin şimdiki koçu ve kurum müdürü. Koç değişince yeni
--    koç tüm geçmişi görür, eski koç göremez. Öğrenci ve veli görmez
--    (kurum içi rehberlik notu).
--  * Değiştirme yok. Yazan 24 saat içinde silebilir (yanlış kayıt), müdür
--    her zaman silebilir. Öğrenci hesabı silinince kayıtları da silinir.
--  * Sağlık gibi özel nitelikli veri için etiket yoktur.
--
-- Geri almak için: supabase/rollbacks/20261031130000_guidance_logs.down.sql
-- =====================================================================

create table public.guidance_logs (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants (id),
  student_id   uuid not null references public.profiles (id) on delete cascade,
  author_id    uuid references public.profiles (id) on delete set null,
  author_name  text not null,
  met_on       date not null,
  kind         text not null
               check (kind in ('in_person', 'phone', 'online', 'parent')),
  topics       text[] not null default '{}'
               check (topics <@ array['academic', 'motivation', 'goals',
                                      'university', 'exam_anxiety', 'time',
                                      'family', 'other']
                      and cardinality(topics) <= 5),
  note         text not null check (length(trim(note)) between 1 and 2000),
  next_step    text check (length(next_step) <= 300),
  follow_up_on date,
  created_at   timestamptz not null default now()
);
create index on public.guidance_logs (student_id, met_on desc);
create index on public.guidance_logs (tenant_id);
create index on public.guidance_logs (author_id);

create or replace function public.guard_guidance_log()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
begin
  if (select role from public.profiles where id = new.student_id) <> 'student' then
    raise exception 'GUIDANCE_NOT_STUDENT';
  end if;
  if new.met_on > v_today or new.met_on < v_today - 60 then
    raise exception 'GUIDANCE_BAD_DATE';
  end if;
  if new.follow_up_on is not null and new.follow_up_on < new.met_on then
    raise exception 'GUIDANCE_BAD_DATE';
  end if;
  new.author_id := auth.uid();
  new.author_name := coalesce(
    (select full_name from public.profiles where id = auth.uid()), '');
  new.created_at := now();
  new.note := trim(new.note);
  new.next_step := nullif(trim(new.next_step), '');
  return new;
end;
$$;
revoke all on function public.guard_guidance_log() from public, anon, authenticated;

create trigger set_tenant_id before insert on public.guidance_logs
  for each row execute function public.set_tenant_id();
create trigger guard_guidance_log before insert on public.guidance_logs
  for each row execute function public.guard_guidance_log();

alter table public.guidance_logs enable row level security;
create policy "manager reads guidance" on public.guidance_logs
  for select to authenticated
  using ((select public.can_manage_student(student_id)));
create policy "manager writes guidance" on public.guidance_logs
  for insert to authenticated
  with check ((select public.can_manage_student(student_id)));
create policy "author or admin deletes guidance" on public.guidance_logs
  for delete to authenticated
  using ((author_id = (select auth.uid())
          and created_at > now() - interval '24 hours'
          and (select public.can_manage_student(student_id)))
         or (select public.is_admin_of_user(student_id)));
create policy "tenant isolation" on public.guidance_logs as restrictive
  for all to public
  using (tenant_id = (select public.my_tenant())
         and (select public.my_tenant_active()))
  with check (tenant_id = (select public.my_tenant())
              and (select public.my_tenant_active()));
revoke all on public.guidance_logs from anon;
revoke update, truncate, trigger, references on public.guidance_logs from authenticated;
