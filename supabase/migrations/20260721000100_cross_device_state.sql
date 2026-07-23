-- Cross-device progress state (additive).
--
-- Two lean tables so a signed-in user can restore their learning progress on
-- a new device. Data-minimal by design: content ids and scheduling numbers
-- only. No education records, no PII, nothing cohort-scoped.
--
--   card_states     one row per (user, card): the FSRS memory state for the
--                   v1 face/concept decks, which are otherwise local-only.
--                   Card ids are public content ids (deck YAML ids, bioguide
--                   ids), never user data.
--   user_app_state  one row per user: chapter position, XP, and deck
--                   subscription prefs as a compact jsonb map.
--
-- Conflict model: the client owns merging. Pushes are plain upserts (the
-- device that played last pushes last); on sign-in the client pulls and
-- merges per-card by last_reviewed_at (newest wins), which is the correct
-- resolution for FSRS scheduling. The server never interprets these rows.
--
-- Apply to production manually (supabase db push) alongside the app build
-- that ships restore; harmless earlier since nothing reads it.

create table public.card_states (
  user_id          uuid not null references public.profiles (id) on delete cascade,
  card_id          text not null check (char_length(card_id) between 1 and 64),
  stability        double precision,
  difficulty       double precision,
  due_at           timestamptz,
  last_reviewed_at timestamptz,
  reps             int not null default 0,
  lapses           int not null default 0,
  is_new           boolean not null default false,
  updated_at       timestamptz not null default now(),
  primary key (user_id, card_id)
);

create index card_states_user_idx on public.card_states (user_id, updated_at);

alter table public.card_states enable row level security;

create policy card_states_select_own on public.card_states
  for select to authenticated using (user_id = auth.uid());
create policy card_states_insert_own on public.card_states
  for insert to authenticated with check (user_id = auth.uid());
create policy card_states_update_own on public.card_states
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update on public.card_states to authenticated;

create table public.user_app_state (
  user_id            uuid primary key references public.profiles (id) on delete cascade,
  chapter_number     int not null default 1 check (chapter_number between 1 and 99),
  day_in_chapter     int not null default 1 check (day_in_chapter between 1 and 99),
  xp                 int not null default 0 check (xp >= 0),
  deck_subscriptions jsonb not null default '{}'::jsonb,
  updated_at         timestamptz not null default now()
);

alter table public.user_app_state enable row level security;

create policy user_app_state_select_own on public.user_app_state
  for select to authenticated using (user_id = auth.uid());
create policy user_app_state_insert_own on public.user_app_state
  for insert to authenticated with check (user_id = auth.uid());
create policy user_app_state_update_own on public.user_app_state
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update on public.user_app_state to authenticated;
