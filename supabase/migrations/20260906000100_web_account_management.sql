-- Web account management: working account deletion, deletion blockers, and
-- cohort ownership transfer.
--
-- Why delete_my_account is replaced: the 20260724000500 version deleted
-- auth.users and relied on cascades that do not exist. events.user_id,
-- mock_attempts.user_id, cohorts.created_by, live_sessions.created_by,
-- class_announcements.author, teaching_inputs.created_by,
-- faculty_invites.minted_by, questions.created_by, and two granted_by
-- columns all FK profiles with no cascade, so deletion failed with a raw FK
-- violation for any user with history. This version does an explicit,
-- ordered teardown.
--
-- Data rules:
--   * Other users' append-only history is never deleted, only unlinked
--     (cohort_id set null) when a leftover solo class is removed.
--   * The caller's own history is erased: that is the promise account
--     deletion makes (Apple 5.1.1(v), data minimization).
--   * Deletion is refused while the caller owns classes that still have
--     other members; they delete the class or transfer ownership first.

-- ── Blockers precheck ───────────────────────────────────────────────────────
-- Classes the caller created that still have members besides the caller.
create or replace function public.account_deletion_blockers()
returns jsonb
language sql security definer set search_path = public, app, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'cohort_id', c.id,
           'name', c.name,
           'others', (select count(*) from public.cohort_members m
                       where m.cohort_id = c.id and m.user_id <> auth.uid())
         ) order by c.name), '[]'::jsonb)
  from public.cohorts c
  where c.created_by = auth.uid()
    and exists (select 1 from public.cohort_members m
                 where m.cohort_id = c.id and m.user_id <> auth.uid());
$$;

revoke execute on function public.account_deletion_blockers() from public, anon;
grant execute on function public.account_deletion_blockers() to authenticated;

-- ── Ownership transfer ──────────────────────────────────────────────────────
-- The creator hands the class to an existing co-faculty member. Unblocks
-- account deletion and covers ordinary faculty turnover.
create or replace function public.transfer_cohort_ownership(
  p_cohort uuid,
  p_new_owner uuid
) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if p_new_owner = v_user then
    raise exception 'You already own this class.';
  end if;
  if not exists (select 1 from public.cohorts
                  where id = p_cohort and created_by = v_user) then
    raise exception 'Only the class creator can transfer ownership.';
  end if;
  if not exists (select 1 from public.cohort_members
                  where cohort_id = p_cohort and user_id = p_new_owner
                    and role = 'faculty') then
    raise exception 'The new owner must already be co-faculty of this class.';
  end if;
  update public.cohorts set created_by = p_new_owner where id = p_cohort;
end;
$$;

revoke execute on function public.transfer_cohort_ownership(uuid, uuid)
  from public, anon;
grant execute on function public.transfer_cohort_ownership(uuid, uuid)
  to authenticated;

-- ── Account deletion, repaired ──────────────────────────────────────────────
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_blocked text;
  v_cohort uuid;
begin
  if v_user is null then raise exception 'not authenticated'; end if;

  -- Refuse while classes with other members are still owned.
  select string_agg(c.name, ', ' order by c.name) into v_blocked
  from public.cohorts c
  where c.created_by = v_user
    and exists (select 1 from public.cohort_members m
                 where m.cohort_id = c.id and m.user_id <> v_user);
  if v_blocked is not null then
    raise exception 'blocked_by_cohorts: %', v_blocked;
  end if;

  -- Remove leftover classes only the caller belongs to. Other users'
  -- history that still points at them (students who left) is unlinked,
  -- never deleted.
  for v_cohort in
    select id from public.cohorts where created_by = v_user
  loop
    -- Cascades assessments and input_items, freeing this class's
    -- faculty-authored questions and live sessions for deletion.
    delete from public.teaching_inputs where cohort_id = v_cohort;
    delete from public.live_sessions where cohort_id = v_cohort;
    update public.events set question_id = null
     where question_id in (select id from public.questions
                            where cohort_id = v_cohort);
    delete from public.questions where cohort_id = v_cohort;
    update public.events set cohort_id = null where cohort_id = v_cohort;
    update public.mock_attempts set cohort_id = null where cohort_id = v_cohort;
    update public.user_domain_readiness set cohort_id = null
     where cohort_id = v_cohort;
    update public.user_objective_readiness set cohort_id = null
     where cohort_id = v_cohort;
    delete from public.redemption_codes where cohort_id = v_cohort;
    delete from public.cohorts where id = v_cohort;
  end loop;

  -- Erase the caller's own trail in classes that survive them.
  update public.assessments set live_session_id = null
   where live_session_id in (select id from public.live_sessions
                              where created_by = v_user);
  delete from public.teaching_inputs where created_by = v_user;
  delete from public.live_sessions where created_by = v_user;
  delete from public.class_announcements where author = v_user;
  delete from public.events where user_id = v_user;
  delete from public.mock_attempts where user_id = v_user;
  delete from public.faculty_invites where minted_by = v_user;
  update public.questions set created_by = null where created_by = v_user;
  update app.verified_faculty set granted_by = null where granted_by = v_user;
  update app.org_admins set granted_by = null where granted_by = v_user;

  -- Cascades to profiles and every cascade-safe table.
  delete from auth.users where id = v_user;
exception
  when foreign_key_violation then
    raise exception 'deletion_incomplete';
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
