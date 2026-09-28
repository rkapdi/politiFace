-- Onboarding phase 1: one console for faculty onboarding and student
-- browser identity (spec 2026-09-27, sections 1 and 2).
--
--   1. Faculty invites become links: expiry, revocation, a recipient hint,
--      and a signed-out preview for the #/welcome page. Staff can mint.
--   2. Faculty access requests: a professor without a link asks; staff
--      approve with one click.
--   3. my_console_role / my_student_classes: the console picks a home.
--   4. Live sessions: a signed-out preview, a member join that enrolls on
--      first use (same account as the iOS app), and guests opt-in.

-- ── 1. invite links ─────────────────────────────────────────────────────────
alter table public.faculty_invites
  add column expires_at timestamptz not null default now() + interval '14 days',
  add column recipient_email text
    check (recipient_email is null or length(recipient_email) <= 254),
  add column revoked_at timestamptz;

drop function public.mint_faculty_invite(text);
create function public.mint_faculty_invite(
  p_note text default null,
  p_recipient_email text default null
) returns text
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_code text;
begin
  if not (app.is_verified_faculty(auth.uid()) or app.is_admin(auth.uid())) then
    raise exception 'only verified faculty can mint invites';
  end if;
  insert into public.faculty_invites (minted_by, note, recipient_email)
  values (auth.uid(), nullif(trim(p_note), ''),
          nullif(lower(trim(p_recipient_email)), ''))
  returning code into v_code;
  return v_code;
end;
$$;
revoke all on function public.mint_faculty_invite(text, text) from public, anon;
grant execute on function public.mint_faculty_invite(text, text) to authenticated;

create function public.revoke_faculty_invite(p_code text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  update public.faculty_invites
     set revoked_at = coalesce(revoked_at, now())
   where code = upper(trim(p_code))
     and (minted_by = auth.uid() or app.is_admin(auth.uid()));
  if not found then raise exception 'invite not found'; end if;
end;
$$;
revoke all on function public.revoke_faculty_invite(text) from public, anon;
grant execute on function public.revoke_faculty_invite(text) to authenticated;

-- Signed-out preview for the welcome page: validity and the inviter's
-- display name only. Nothing else about the invite leaves the server.
create function public.invite_preview(p_code text) returns jsonb
language sql stable security definer set search_path = public, app, pg_temp as $$
  select coalesce(
    (select jsonb_build_object(
              'valid', i.revoked_at is null and i.expires_at > now()
                       and i.uses < i.max_uses,
              'inviter', p.handle)
       from public.faculty_invites i
       join public.profiles p on p.id = i.minted_by
      where i.code = upper(trim(p_code))),
    jsonb_build_object('valid', false, 'inviter', null));
$$;
grant execute on function public.invite_preview(text) to anon, authenticated;

create or replace function public.redeem_faculty_invite(p_code text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_row public.faculty_invites%rowtype;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  select * into v_row from public.faculty_invites
   where code = upper(trim(p_code)) for update;
  if not found or v_row.uses >= v_row.max_uses
     or v_row.revoked_at is not null or v_row.expires_at <= now() then
    raise exception 'invalid or exhausted invite code';
  end if;
  update public.faculty_invites set uses = uses + 1 where code = v_row.code;
  insert into app.verified_faculty (user_id, granted_by, note)
  values (v_user, v_row.minted_by, v_row.note)
  on conflict (user_id) do nothing;
end;
$$;
