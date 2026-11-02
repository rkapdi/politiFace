#!/bin/sh
# Runs the app's regression gate locally, exactly as Flutter CI does:
# codegen, analyze (fails on warnings and errors), the smoke test that opens
# every screen, then every test. Run it before pushing any app change.
#
#   scripts/check-app.sh          full gate (about a minute)
#   scripts/check-app.sh --smoke  smoke test only (seconds)
#
# Uses Flutter 3.22.0, the version CI pins. Override with FLUTTER=/path.
set -eu

cd "$(dirname "$0")/../app"

want=3.22.0
if [ -z "${FLUTTER:-}" ]; then
  if [ -x "$HOME/fvm/versions/$want/bin/flutter" ]; then
    FLUTTER="$HOME/fvm/versions/$want/bin/flutter"
  else
    FLUTTER=flutter
  fi
fi
have=$("$FLUTTER" --version --machine 2>/dev/null \
  | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')
if [ "$have" != "$want" ]; then
  echo "check-app: need Flutter $want (CI pins it), found '${have:-none}' at $FLUTTER." >&2
  echo "Install it with: fvm install $want   (or set FLUTTER=/path/to/flutter)" >&2
  exit 1
fi
DART="$(dirname "$FLUTTER")/dart"

# Shaders cached by a different Flutter version crash 3.22 widget tests
# (InkSparkle RangeError). The folder is rebuilt on every test run.
rm -rf build/unit_test_assets

if [ "${1:-}" = "--smoke" ]; then
  exec "$FLUTTER" test test/smoke
fi

echo "== pub get"
"$FLUTTER" pub get >/dev/null
if ! git diff --quiet -- pubspec.lock; then
  echo "check-app: pubspec.lock changed. Commit it only if you meant to change dependencies." >&2
fi

echo "== codegen"
"$DART" run build_runner build --delete-conflicting-outputs >/dev/null
if [ -n "$(git status --porcelain -- 'lib/**.g.dart' 'lib/*.g.dart')" ]; then
  echo "check-app: generated code was stale and has been regenerated; commit the .g.dart changes." >&2
fi

echo "== analyze"
out=$("$FLUTTER" analyze 2>&1 || true)
if printf '%s\n' "$out" | grep -qE "^\s*(warning|error) •"; then
  printf '%s\n' "$out" | grep -E "^\s*(warning|error) •" >&2
  echo "check-app: analyze found warnings or errors." >&2
  exit 1
fi
echo "OK: no warnings or errors"

echo "== smoke test (every screen opens)"
"$FLUTTER" test test/smoke

echo "== all tests"
"$FLUTTER" test

echo "check-app: all green."
