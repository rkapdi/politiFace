-- Account management: editable display name (handle), a curated avatar,
-- editable school label, and account deletion.
--
-- Design choices that keep the compliance story clean:
--   * Avatars are a preset id (0..N), not an uploaded image. No photos of
--     students are ever stored, so no moderation, no CSAM surface, no PII,
--     no storage. Same "make it mine" feel, HECVAT-friendly.
--   * The handle stays the pseudonymous leaderboard identity; users may now
--     choose it (validated + unique) instead of the generated one. Real
--     names live only in roster_name (faculty-of-that-cohort only).
--   * delete_my_account satisfies Apple guideline 5.1.1(v): the user can
--     erase their account and all derived data from inside the app.

alter table public.profiles
  add column avatar_id smallint not null default 0
    check (avatar_id between 0 and 47);

-- Update the caller's own profile. Handle uniqueness is enforced by the
-- lower() unique index; we surface a clean error on collision.
create function public.update_my_profile(
  p_handle text default null,
  p_school text default null,
  p_avatar_id smallint default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'not authenticated'; end if;

  if p_handle is not null then
    if p_handle !~ '^[A-Za-z0-9_]{3,20}$' then
      raise exception 'Handle must be 3 to 20 letters, numbers, or underscores.';
    end if;
    if exists (select 1 from public.profiles
                where lower(handle) = lower(trim(p_handle)) and id <> v_user) then
      raise exception 'That handle is taken.';
    end if;
    update public.profiles set handle = trim(p_handle) where id = v_user;
  end if;

  if p_school is not null then
    update public.profiles
       set school = nullif(trim(p_school), '') where id = v_user;
  end if;

  if p_avatar_id is not null then
    if p_avatar_id < 0 or p_avatar_id > 47 then
      raise exception 'invalid avatar';
    end if;
    update public.profiles set avatar_id = p_avatar_id where id = v_user;
  end if;

  return (select jsonb_build_object(
            'handle', handle, 'school', school, 'avatar_id', avatar_id)
          from public.profiles where id = v_user);
end;
$$;

-- Full account deletion. Deleting the auth.users row cascades to profiles
-- (on delete cascade) and everything that FKs profiles: memberships,
-- events, mock attempts, tokens, live answers, card/app state. The caller
-- can only ever delete themselves.
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = v_user;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
revoke execute on function public.update_my_profile(text, text, smallint)
  from public, anon;
grant execute on function public.update_my_profile(text, text, smallint)
  to authenticated;
