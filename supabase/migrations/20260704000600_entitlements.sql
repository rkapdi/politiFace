-- Entitlements. RevenueCat is the source of truth for purchases; its webhook
-- (an Edge Function running as service role) writes here. Redemption codes
-- are the institutional rail: a code comped to a cohort means students never
-- see a paywall. The app checks capability only.

create table public.entitlements (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  capability text not null check (capability in ('full', 'fcle', 'plus')),
  source     text not null check (source in ('institutional', 'purchase', 'promo')),
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  primary key (user_id, capability)
);

create table public.redemption_codes (
  code       text primary key,
  cohort_id  uuid references public.cohorts (id),
  capability text not null check (capability in ('full', 'fcle', 'plus')),
  max_uses   int,
  uses       int not null default 0,
  expires_at timestamptz
);

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.entitlements     enable row level security;
alter table public.redemption_codes enable row level security;

grant select on public.entitlements to authenticated;
-- redemption_codes: no client grants at all; redeem_code (SECURITY DEFINER)
-- validates and burns codes, service role provisions them.

create policy entitlements_select_own on public.entitlements for select
  to authenticated using (user_id = auth.uid());
