-- Teacher-to-class announcements: a professor sends a short message that
-- lands as a visible push on their students' phones. Unlike the Washington
-- silent wake, this is an ALERT push with real text: the teacher wrote it,
-- so there is no on-device relevance question and no server behavioral
-- profile involved. It is a message from your professor.
--
-- Stored so students can also see a class inbox in-app (delivery is
-- best-effort; the record is the source of truth). Rate-limited per
-- teacher so the megaphone stays a megaphone, not a firehose.

create table public.class_announcements (
  id         uuid primary key default gen_random_uuid(),
  cohort_id  uuid not null references public.cohorts (id) on delete cascade,
  author     uuid not null references public.profiles (id),
  body       text not null check (length(trim(body)) between 1 and 240),
  created_at timestamptz not null default now()
);

create index class_announcements_cohort_idx
  on public.class_announcements (cohort_id, created_at desc);

alter table public.class_announcements enable row level security;

-- Members read their cohorts' announcements (the in-app class inbox).
create policy class_announcements_select_members on public.class_announcements
  for select to authenticated
  using (app.is_cohort_member(cohort_id));

grant select on public.class_announcements to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.class_announcements;
  end if;
end $$;

-- Faculty send. Rate limit: at most 5 in a rolling hour, 20 in a day, per
-- cohort. Returns the new row id + the count of student devices that will
-- be targeted (the actual push is sent by the class-announce Edge Function,
-- which reads this row).
create function public.send_class_announcement(p_cohort uuid, p_body text)
returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_id uuid;
  v_recent int;
  v_daily int;
  v_devices int;
begin
  if not app.is_cohort_faculty(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  if length(trim(coalesce(p_body, ''))) < 1 then
    raise exception 'message is empty';
  end if;
  if length(trim(p_body)) > 240 then
    raise exception 'message is too long (240 characters max)';
  end if;

  select count(*) into v_recent from public.class_announcements
   where cohort_id = p_cohort and created_at > now() - interval '1 hour';
  if v_recent >= 5 then
    raise exception 'too many messages this hour (5 max); try again shortly';
  end if;
  select count(*) into v_daily from public.class_announcements
   where cohort_id = p_cohort and created_at > now() - interval '1 day';
  if v_daily >= 20 then
    raise exception 'daily message limit reached for this class';
  end if;

  insert into public.class_announcements (cohort_id, author, body)
  values (p_cohort, auth.uid(), trim(p_body))
  returning id into v_id;

  select count(distinct t.token) into v_devices
    from public.push_tokens t
    join public.cohort_members m
      on m.user_id = t.user_id and m.cohort_id = p_cohort
   where m.role = 'student';

  return jsonb_build_object('id', v_id, 'devices', v_devices);
end;
$$;
