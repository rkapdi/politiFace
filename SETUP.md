# SETUP.md — Politiface Development Environment

The app is fully offline (local SQLite only) — there is no backend to set up.

## Prerequisites

### 1. Flutter SDK 3.22.x

```bash
# macOS (recommended: use FVM for version management)
brew install fvm
fvm install 3.22.0
fvm global 3.22.0

flutter --version   # should show 3.22.0
flutter doctor      # Xcode required for the iOS target
```

**Flutter doctor checklist (iOS-only V1):**
- [ ] Flutter (channel stable) ✓
- [ ] Xcode ✓
- [ ] iOS Simulator or connected iPhone ✓

### 2. Editor

VS Code with the **Dart** and **Flutter** extensions (the **Drift** and **YAML**
extensions are nice to have for schema and content work), or Android Studio /
IntelliJ with the Flutter plugin.

### 3. Python 3 (content scripts only)

Only needed if you work on content tooling (`scripts/`):

```bash
pip3 install pyyaml requests
```

## Build and run

```bash
git clone https://github.com/politiface/politiface.git
cd politiface/app

flutter pub get
flutter test        # must pass before you change anything
flutter run         # launches on the open iOS simulator
```

The app seeds its SQLite database from bundled YAML (`app/assets/content/`) on
first launch. No environment variables or `.env` file are required. Crash
reporting (Sentry) no-ops in local builds because no DSN is compiled in.

## Code generation (Drift)

Generated `*.g.dart` files are committed. Re-run codegen only when you change
database tables or DAOs:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Content pipeline

- Decks: `app/assets/content/decks/*.yaml`
- Curriculum: `app/assets/content/curriculum/us_civics.yaml`
- Government structure: `content/governments/us/government.yaml`
  (validated in CI by `scripts/validate_government.py`)
- Portraits: fetched by `scripts/fetch_wikidata_portraits.py`, wired into deck
  YAML by `scripts/wire_portraits.py`

## Troubleshooting

**`flutter test` fails on a fresh clone** — run `flutter pub get` first and
confirm `flutter --version` shows 3.22.x; the project is pinned to that
toolchain.

**Stale generated code after a schema change** — re-run the build_runner
command above; never hand-edit `*.g.dart`.

**iOS build issues** — `cd app/ios && pod install`, then retry. The Podfile
disables codesigning for Debug builds.
