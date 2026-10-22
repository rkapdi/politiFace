-- Co-instructors: let a class's existing faculty add a verified faculty
-- colleague as co-faculty on the same cohort, so two instructors can run
-- live sessions, announcements, and reports together.
--
-- Safety model:
--   * Caller must already be faculty OF THIS COHORT (not just verified
--     faculty anywhere), so possession of a projected join code never
--     grants console access.
--   * Target is looked up by exact email and must have redeemed a faculty
--     invite (app.verified_faculty). Students can never be escalated by
--     this path, and typos fail loudly instead of silently inviting the
--     wrong account.
--   * Idempotent: adding an existing member upgrades their role to
--     faculty; adding twice is a no-op.

create function public.add_co_faculty(p_cohort uuid, p_email text)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_caller uuid := auth.uid();
  v_target uuid;
begin
  if v_caller is null then raise exception 'not authenticated'; end if;
  if not exists (
    select 1 from public.cohort_members
     where cohort_id = p_cohort and user_id = v_caller and role = 'faculty'
  ) then
    raise exception 'only this class'' faculty can add co-instructors';
  end if;

  select u.id into v_target
    from auth.users u
   where lower(u.email) = lower(trim(p_email));
  if v_target is null then
    raise exception 'no Politiface account uses that email';
  end if;
  if not app.is_verified_faculty(v_target) then
    raise exception
      'that account has not redeemed a faculty invite code yet';
  end if;

  insert into public.cohort_members (cohort_id, user_id, role)
  values (p_cohort, v_target, 'faculty')
  on conflict (cohort_id, user_id) do update set role = 'faculty';
end;
$$;

revoke all on function public.add_co_faculty(uuid, text) from public;
grant execute on function public.add_co_faculty(uuid, text) to authenticated;
