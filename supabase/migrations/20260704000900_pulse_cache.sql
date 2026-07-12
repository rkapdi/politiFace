-- Server-side cache for the Pulse feed proxy. The congress.gov API key
-- cannot ship inside the public client, so the `pulse` Edge Function
-- fetches with the key server-side and caches here; clients only ever see
-- the function's output. RLS is enabled with NO policies and NO grants:
-- invisible to every client role, while the service role (bypassrls)
-- reads and writes it.

create table public.pulse_cache (
  key        text primary key,          -- e.g. 'bills'
  payload    jsonb not null,
  fetched_at timestamptz not null default now()
);

alter table public.pulse_cache enable row level security;
