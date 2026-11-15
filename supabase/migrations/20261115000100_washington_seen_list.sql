-- Washington watch: a seen-list for White House actions, so the same
-- action can never alert twice.
--
-- Until now the White House tier kept ONE watermark: the id of the newest
-- feed entry (app.push_signal.last_wh). "Is this new?" meant "is the entry
-- at the top of the feed different from the one I stored?". That is only
-- true while the feed strictly appends. It breaks whenever the top of the
-- feed changes for any other reason:
--   * an entry is edited and moves, or two entries swap order;
--   * the newest entry is withdrawn, so yesterday's entry is on top again;
--   * two actions are posted between polls, and the older one later
--     surfaces as "newest".
-- Each of those sent a visible alert for an action people had already been
-- told about.
--
-- The fix: remember every entry ever observed (app.wh_seen, keyed by the
-- feed's guid). An entry alerts once, the first time it is observed, and
-- never again, whatever the feed does afterwards. The whole decision is one
-- transaction under the push_signal row lock, so two overlapping polls (the
-- cron and a manual trigger) cannot both see the same entry as new.
--
-- Rollout is safe in either order:
--   * This migration first, the new push-washington function later: the old
--     function keeps calling washington_advance, which is kept below as a
--     thin wrapper over the new logic.
--   * The new function first: its call to washington_poll fails loudly
--     (visible in the function's response and logs) and it sends nothing
--     until this migration is applied.

-- ── the seen-list ───────────────────────────────────────────────────────────
create table app.wh_seen (
  guid          text primary key,
  title         text,
  published_at  timestamptz,
  first_seen_at timestamptz not null default now()
);
comment on table app.wh_seen is
  'Every White House feed entry push-washington has observed. An entry can '
  'alert only on the poll that first inserts it here.';

-- No client role may touch it (the app schema is not exposed, and schema
-- usage is already revoked from clients; this is belt and braces).
revoke all on table app.wh_seen from public, anon, authenticated;
grant select, insert, update, delete on table app.wh_seen to service_role;

comment on column app.push_signal.last_wh is
  'Diagnostic only since 20261115000100: the newest White House guid last '
  'observed. It no longer decides what is new; app.wh_seen does.';

-- Timestamps arrive as text from a feed we do not control. A malformed
-- one must read as "unknown", never abort the poll.
create function app.safe_timestamptz(p_text text) returns timestamptz
language plpgsql immutable set search_path = pg_catalog, pg_temp as $$
begin
  if p_text is null or btrim(p_text) = '' then
    return null;
  end if;
  return p_text::timestamptz;
exception when others then
  return null;
end;
$$;
revoke all on function app.safe_timestamptz(text)
  from public, anon, authenticated;
grant execute on function app.safe_timestamptz(text) to service_role;

-- ── seed: everything already announced counts as seen ───────────────────────
-- Without this, the first poll after deploy would find up to ten "unseen"
-- entries (the whole current feed window). The function mirrors the feed
-- into pulse_cache on every poll, so that mirror plus the old watermark is
-- exactly the set of entries already known.
insert into app.wh_seen (guid, title, published_at)
select a ->> 'guid',
       a ->> 'title',
       app.safe_timestamptz(a ->> 'published_at')
  from public.pulse_cache c
  cross join lateral jsonb_array_elements(c.payload) a
 where c.key = 'presidential_actions'
   and jsonb_typeof(c.payload) = 'array'
   and coalesce(a ->> 'guid', '') <> ''
on conflict (guid) do nothing;

insert into app.wh_seen (guid)
select last_wh from app.push_signal where id and last_wh is not null
on conflict (guid) do nothing;

-- ── the poll state machine ──────────────────────────────────────────────────
-- Called by push-washington each poll with everything it observed. Nulls
-- mean "upstream hiccup": a null never regresses a watermark and never
-- fires.
--
-- p_wh is the White House feed window as a JSON array, newest first:
--   [{"guid": "...", "title": "...", "url": "...", "kind": "...",
--     "published_at": "2026-11-15T14:00:00Z"}, ...]
--
-- Returns:
--   first_run  the congress.gov / Federal Register watermarks were all
--              empty, so this poll baselined them silently
--   changed    something is worth a push (a watermark moved, or wh_new is
--              not empty)
--   eo_new     the Federal Register executive order number moved
--   wh_new     JSON array of the White House entries that are new on THIS
--              poll, newest first, in the shape they were passed in. Each
--              entry appears here at most once, ever.
--
-- White House rules:
--   * An entry already in app.wh_seen is never new, whatever its position.
--   * The first poll that observes anything while the seen-list is empty
--     baselines silently (records, alerts nothing).
--   * An unseen entry published more than p_max_age ago is recorded but not
--     alerted: it is the feed window sliding back over old history, not
--     news. An entry with no readable publish time is treated as fresh.
create function public.washington_poll(
  p_eo int default null,
  p_bill date default null,
  p_law text default null,
  p_wh jsonb default null,
  p_max_age interval default interval '3 days'
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  sig app.push_signal%rowtype;
  v_first boolean;
  v_eo boolean;
  v_bill boolean;
  v_law boolean;
  v_wh_baseline boolean;
  v_wh_new jsonb := '[]'::jsonb;
  v_newest text;
begin
  -- The row lock serializes overlapping polls: the second one waits here
  -- and then finds everything the first one recorded.
  select * into sig from app.push_signal where id for update;

  v_first := sig.last_eo_number is null and sig.last_law is null
             and sig.last_bill_date is null and sig.last_wh is null;
  v_eo   := p_eo   is not null and p_eo   is distinct from sig.last_eo_number;
  v_bill := p_bill is not null and p_bill is distinct from sig.last_bill_date;
  v_law  := p_law  is not null and p_law  is distinct from sig.last_law;

  if p_wh is not null and jsonb_typeof(p_wh) = 'array' then
    v_wh_baseline := not exists (select 1 from app.wh_seen);

    with observed as (
      -- One row per guid, keeping its first (newest) position.
      select distinct on (e.item ->> 'guid')
             e.item ->> 'guid' as guid,
             e.item ->> 'title' as title,
             app.safe_timestamptz(e.item ->> 'published_at') as published_at,
             e.item as item,
             e.ord
        from jsonb_array_elements(p_wh) with ordinality as e(item, ord)
       where coalesce(e.item ->> 'guid', '') <> ''
       order by e.item ->> 'guid', e.ord
    ),
    inserted as (
      insert into app.wh_seen (guid, title, published_at)
      select guid, title, published_at from observed
      on conflict (guid) do nothing
      returning guid
    )
    select coalesce(jsonb_agg(o.item order by o.ord), '[]'::jsonb)
      into v_wh_new
      from observed o
      join inserted i using (guid)
     where not v_wh_baseline
       and (o.published_at is null or o.published_at >= now() - p_max_age);

    select e.item ->> 'guid' into v_newest
      from jsonb_array_elements(p_wh) with ordinality as e(item, ord)
     where coalesce(e.item ->> 'guid', '') <> ''
     order by e.ord
     limit 1;

    -- Keep the list bounded. An entry this old that reappears is caught by
    -- the p_max_age rule above, so forgetting it cannot cause an alert.
    delete from app.wh_seen s
     where s.first_seen_at < now() - interval '365 days'
       and not exists (
         select 1 from jsonb_array_elements(p_wh) e
          where e ->> 'guid' = s.guid);
  end if;

  update app.push_signal set
    last_eo_number = coalesce(p_eo, last_eo_number),
    last_bill_date = coalesce(p_bill, last_bill_date),
    last_law       = coalesce(p_law, last_law),
    last_wh        = coalesce(v_newest, last_wh),
    updated_at     = now()
  where id;

  return jsonb_build_object(
    'first_run', v_first,
    'changed', ((not v_first) and (v_eo or v_bill or v_law))
               or jsonb_array_length(v_wh_new) > 0,
    'eo_new', (not v_first) and v_eo,
    'wh_new', v_wh_new);
end;
$$;
revoke all on function public.washington_poll(int, date, text, jsonb, interval)
  from public, anon, authenticated;
grant execute on function public.washington_poll(int, date, text, jsonb, interval)
  to service_role;

-- ── the old entry point, kept for the function version deployed today ───────
-- Same signature and same return shape as before, now decided by the
-- seen-list. It only ever learns the single newest entry per poll, so it
-- cannot apply the publish-age rule; the new function passes the whole
-- feed window to washington_poll instead.
create or replace function public.washington_advance(
  p_eo int default null,
  p_bill date default null,
  p_law text default null,
  p_wh text default null,
  p_wh_title text default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  r jsonb;
begin
  r := public.washington_poll(
    p_eo, p_bill, p_law,
    case when p_wh is null then null
         else jsonb_build_array(
           jsonb_build_object('guid', p_wh, 'title', p_wh_title))
    end);
  return jsonb_build_object(
    'first_run', r -> 'first_run',
    'changed', r -> 'changed',
    'wh_new', jsonb_array_length(r -> 'wh_new') > 0,
    'eo_new', r -> 'eo_new',
    'wh_title', p_wh_title);
end;
$$;
revoke all on function public.washington_advance(int, date, text, text, text)
  from public, anon, authenticated;
grant execute on function public.washington_advance(int, date, text, text, text)
  to service_role;
