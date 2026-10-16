-- Geri alma: 20261018150000_drop_foreign_consent_survey_tables
-- Tabloları canlıdaki ilk halleriyle (create_consent_and_survey_tables)
-- yeniden oluşturur. Not: o haliyle giriş yapan herkes okuyabilir, giriş
-- yapmayan herkes yazabilir.

create table if not exists public.cookie_consents (
  id                 uuid primary key default gen_random_uuid(),
  consent_state      text not null check (consent_state in ('accepted', 'declined', 'customized')),
  consent_categories jsonb,
  language           text,
  screen_resolution  text,
  referrer           text,
  page_url           text,
  user_agent         text,
  ip_address         text,
  country            text,
  city               text,
  is_bot             boolean default false,
  created_at         timestamptz default now()
);
alter table public.cookie_consents enable row level security;
create policy "Public insert consent" on public.cookie_consents for insert with check (true);
create policy "Admin read consent" on public.cookie_consents for select using (auth.role() = 'authenticated');

create table if not exists public.survey_responses (
  id          uuid primary key default gen_random_uuid(),
  source      text not null,
  other_text  text,
  ip_address  text,
  country     text,
  city        text,
  user_agent  text,
  page_url    text,
  is_bot      boolean default false,
  created_at  timestamptz default now()
);
alter table public.survey_responses enable row level security;
create policy "Public insert survey" on public.survey_responses for insert with check (true);
create policy "Admin read survey" on public.survey_responses for select using (auth.role() = 'authenticated');
