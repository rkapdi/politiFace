-- Push delivery: device tokens + a debounced signal queue.
--
-- Data-minimal by construction: a device token is an opaque APNs handle,
-- not identity, and rows are owner-only. The token is what a silent push
-- wakes; the phone's on-device brain then decides whether to actually
-- surface anything (relevance, budget, quiet hours), so the server never
-- holds a behavioral profile. The push payload carries a category and a
-- deep-link only, never notification text.

create table public.push_tokens (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  token       text not null,
  platform    text not null default 'ios' check (platform in ('ios')),
  environment text not null default 'production'
              check (environment in ('production', 'sandbox')),
  updated_at  timestamptz not null default now(),
  primary key (user_id, token)
);

create index push_tokens_token_idx on public.push_tokens (token);

alter table public.push_tokens enable row level security;

create policy push_tokens_select_own on public.push_tokens
  for select to authenticated using (user_id = auth.uid());
create policy push_tokens_insert_own on public.push_tokens
  for insert to authenticated with check (user_id = auth.uid());
create policy push_tokens_update_own on public.push_tokens
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy push_tokens_delete_own on public.push_tokens
  for delete to authenticated using (user_id = auth.uid());

grant select, insert, update, delete on public.push_tokens to authenticated;

create function public.register_push_token(
  p_token text,
  p_environment text default 'production'
) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if length(trim(coalesce(p_token, ''))) < 32 then
    raise exception 'invalid device token';
  end if;
  insert into public.push_tokens (user_id, token, environment, updated_at)
  values (auth.uid(), trim(p_token),
          case when p_environment = 'sandbox' then 'sandbox' else 'production' end,
          now())
  on conflict (user_id, token) do update
    set environment = excluded.environment, updated_at = now();
end;
$$;

create function public.unregister_push_token(p_token text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  delete from public.push_tokens
   where user_id = auth.uid() and token = trim(p_token);
end;
$$;

-- ── the Washington signal the poller writes and the sender drains ───────────
-- A single-row watermark of what the server has seen, plus a pending flag.
-- The poller (pg_cron) compares live sources to this and, on new activity,
-- raises the flag; the sender fans out a silent wake to every token, then
-- lowers it. Debounced by construction: many events between sends collapse
-- into one wake.

create table app.push_signal (
  id             boolean primary key default true check (id),
  last_eo_number int,
  last_law       text,
  last_bill_date date,
  pending        boolean not null default false,
  updated_at     timestamptz not null default now()
);
insert into app.push_signal (id) values (true) on conflict do nothing;
