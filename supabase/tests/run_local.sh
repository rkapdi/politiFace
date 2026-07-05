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
echo "OK: migrations + smoke test passed"
