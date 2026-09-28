-- Display names with spaces: "Purcell Demo", "José Martínez", "Dr. O'Brien".
--
-- The handle was username-shaped (letters, digits, underscore, 3 to 20),
-- which refused real names on the educator side. The new rule is a strict
-- superset of the old one, so every existing handle stays valid:
--   * words of letters (accented included), digits, and _ . ' -
--   * single spaces between words; no leading, trailing, or doubled spaces
--   * 3 to 30 characters, unique ignoring case (profiles_handle_lower_idx)
-- Markup characters and emoji stay out.
--
-- The checks run under the ICU root collation so "letter" means a Unicode
-- letter whatever the database locale: under the C locale (the CI smoke
-- database) [[:alnum:]] is ASCII-only and would refuse "José".
--
-- The iOS app has no client-side rule and shows the server message
-- verbatim, so both apps pick this up without a release.

alter table public.profiles drop constraint profiles_handle_check;
alter table public.profiles add constraint profiles_handle_check
  check (
    (handle collate "und-x-icu") ~ '^[[:alnum:]_.''-]+( [[:alnum:]_.''-]+)*$'
    and char_length(handle) between 3 and 30
  );

-- Recreated verbatim except the handle block, which now collapses runs of
-- whitespace before checking, so "Purcell   Demo" saves as "Purcell Demo".
create or replace function public.update_my_profile(
  p_handle text default null,
  p_school text default null,
  p_avatar_id smallint default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_handle text;
begin
  if v_user is null then raise exception 'not authenticated'; end if;

  if p_handle is not null then
    v_handle := regexp_replace(trim(p_handle), '\s+', ' ', 'g');
    if (v_handle collate "und-x-icu") !~ '^[[:alnum:]_.''-]+( [[:alnum:]_.''-]+)*$'
       or char_length(v_handle) not between 3 and 30 then
      raise exception 'Display names use 3 to 30 letters, numbers, spaces, or . '' - _';
    end if;
    if exists (select 1 from public.profiles
                where lower(handle) = lower(v_handle) and id <> v_user) then
      raise exception 'That handle is taken.';
    end if;
    update public.profiles set handle = v_handle where id = v_user;
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
