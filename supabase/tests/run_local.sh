#!/usr/bin/env bash
# Validate the migrations + RLS + RPCs against a throwaway plain-Postgres
# cluster (no Docker needed). Uses a small shim for the Supabase auth schema.
#
#   brew install postgresql@17
#   ./supabase/tests/run_local.sh
set -euo pipefail

PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@17/bin}"
PORT="${PORT:-55433}"
WORK="$(mktemp -d)"
trap '"$PGBIN/pg_ctl" -D "$WORK/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$WORK"' exit

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

"$PGBIN/initdb" -D "$WORK/data" -U postgres --no-locale -E UTF8 >/dev/null
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -c unix_socket_directories=''" \
  -l "$WORK/pg.log" start >/dev/null
sleep 1
"$PGBIN/createdb" -h 127.0.0.1 -p "$PORT" -U postgres politiface_test

PSQL=("$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d politiface_test
      -v ON_ERROR_STOP=1 -q)

"${PSQL[@]}" -f "$REPO/supabase/tests/shim_auth.sql"
for f in "$REPO"/supabase/migrations/*.sql; do
  echo "migrate: $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
"${PSQL[@]}" -f "$REPO/supabase/tests/smoke.sql"

# Overlapping polls (the cron and a manual trigger at the same moment) must
# not both report the same White House entry as new. Session A observes a
# new entry and holds its transaction open; session B observes the same
# entry meanwhile. B has to wait for A, then find nothing new.
RACE='[{"guid":"race-1","title":"Race"}]'
"${PSQL[@]}" -At -c "begin; \
  select 'A:' || jsonb_array_length(public.washington_poll(null, null, null, '$RACE'::jsonb) -> 'wh_new'); \
  select pg_sleep(2); commit;" > "$WORK/race_a.out" &
sleep 0.7
"${PSQL[@]}" -At -c "select 'B:' || jsonb_array_length(public.washington_poll(null, null, null, '$RACE'::jsonb) -> 'wh_new');" > "$WORK/race_b.out"
wait
if ! grep -qx 'A:1' "$WORK/race_a.out" || ! grep -qx 'B:0' "$WORK/race_b.out"; then
  echo "FAIL: overlapping polls both reported the same entry"
  cat "$WORK/race_a.out" "$WORK/race_b.out"
  exit 1
fi
echo "OK: migrations + smoke test passed"
