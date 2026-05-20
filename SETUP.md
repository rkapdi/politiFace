# SETUP.md — Politiface Development Environment

Follow this exactly. Each step must complete before the next.

---

## Prerequisites to Install

### 1. Flutter SDK

```bash
# macOS (recommended: use FVM for version management)
brew install fvm
fvm install 3.22.0
fvm global 3.22.0

# Verify
flutter --version
# Should show: Flutter 3.22.0

# Run the Flutter doctor — fix everything it flags
flutter doctor
```

**Flutter doctor checklist:**
- [ ] Flutter (channel stable) ✓
- [ ] Android toolchain ✓ (Android Studio or command line tools)
- [ ] Xcode ✓ (macOS only — required for iOS)
- [ ] VS Code or Android Studio ✓
- [ ] Connected device or simulator ✓

### 2. VS Code Extensions

Install these — they are required, not optional:

- **Dart** (dart-code.dart-code)
- **Flutter** (dart-code.flutter)
- **Drift** (drift-db.drift) — SQLite schema support
- **YAML** (redhat.vscode-yaml) — for content YAML files
- **GitLens** (eamodio.gitlens)

### 3. Supabase CLI

```bash
brew install supabase/tap/supabase

# Verify
supabase --version
# Should show 1.x.x
```

### 4. Python 3.12+

```bash
# macOS
brew install python@3.12

# Verify
python3 --version
# Should show 3.12.x

# Install content pipeline dependencies
pip3 install pyyaml jsonschema supabase requests
```

---

## Step 1: Clone and Structure

```bash
# Clone the repo (use your fork URL if you have one)
git clone https://github.com/politiface/politiface.git
cd politiface

# Verify the project structure looks like this:
ls
# app/          content/      supabase/     scripts/
# .github/      README.md     CONTRIBUTING.md
```

---

## Step 2: Set Up Supabase (Local)

```bash
# Initialize Supabase in the project root
supabase init

# Start local Supabase (starts Postgres, Auth, Storage, Studio)
supabase start

# This will output something like:
#   API URL: http://localhost:54321
#   DB URL: postgresql://postgres:postgres@localhost:54322/postgres
#   Studio URL: http://localhost:54323
#   Anon key: eyJhbGci...

# Apply the schema migration
supabase db push

# Verify in Studio: open http://localhost:54323
# You should see all the tables in the Table Editor
```

---

## Step 3: Seed Local Content

```bash
# From project root
export SUPABASE_URL=http://localhost:54321
export SUPABASE_SERVICE_KEY=your-local-service-key  # from supabase start output

# Seed the US government structure
python3 scripts/seed_governments.py content/governments/

# Verify: check Studio → Table Editor → gov_nodes
# Should see nodes like us-node-president, us-node-senate, etc.
```

---

## Step 4: Set Up Flutter App

```bash
cd app

# Copy environment file
cp .env.example .env

# Edit .env with your local Supabase credentials:
# SUPABASE_URL=http://localhost:54321
# SUPABASE_ANON_KEY=your-local-anon-key-from-supabase-start
```

Edit `.env` now before continuing.

```bash
# Install Flutter dependencies
flutter pub get

# Generate code (Drift database + Riverpod providers)
# This MUST run every time you change database tables or add providers
dart run build_runner build --delete-conflicting-outputs

# Verify generation succeeded — these files should now exist:
ls lib/core/database/drift/
# app_database.dart  app_database.g.dart  ← .g.dart is the generated file
```

---

## Step 5: Run the Tests

```bash
# From app/ directory
flutter test test/

# Pay special attention to FSRS tests:
flutter test test/features/session/domain/fsrs_algorithm_test.dart -v

# All tests must pass before you write any new code.
# If FSRS tests fail, the scheduling algorithm is broken.
```

---

## Step 6: Run the App

```bash
# List available devices
flutter devices

# Run on iOS simulator (macOS only)
flutter run -d "iPhone 15 Pro"

# Run on Android emulator
flutter run -d emulator-5554

# Run on web (Chrome)
flutter run -d chrome

# Run on all platforms simultaneously (useful for cross-platform testing)
# Not recommended for daily dev — pick one platform
```

---

## Step 7: Set Up Remote Supabase (for TestFlight/Play Store builds)

1. Create a project at https://supabase.com (free tier)
2. Go to Project Settings → API
3. Copy Project URL and anon key
4. Apply the migration:

```bash
# Link to your remote project
supabase link --project-ref your-project-ref

# Push the schema
supabase db push
```

5. Add to `.env`:
```
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-remote-anon-key
```

6. Add GitHub Secrets (for CI/CD):
- `SUPABASE_URL`
- `SUPABASE_SERVICE_KEY` (the service_role key, NOT the anon key)

---

## Day-to-Day Development Workflow

```bash
# Start of day: ensure local Supabase is running
supabase start

# After changing any Drift table or Riverpod provider:
dart run build_runner build --delete-conflicting-outputs

# Before committing:
flutter test          # all tests pass
flutter analyze       # no lint errors

# To run the YAML validation script locally before pushing:
python3 scripts/validate_government.py content/governments/us/government.yaml
```

---

## Common Issues and Fixes

**`flutter pub get` fails with version conflict**
```bash
flutter pub upgrade
dart run build_runner build --delete-conflicting-outputs
```

**`build_runner` generates conflicting output**
```bash
# Always use --delete-conflicting-outputs
dart run build_runner build --delete-conflicting-outputs
```

**Supabase local not starting**
```bash
supabase stop
supabase start
```

**`app_database.g.dart` not found**
```bash
# Run build_runner — it generates this file
dart run build_runner build --delete-conflicting-outputs
```

**Flutter doctor shows Xcode issues (macOS)**
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

**Android emulator slow**
Make sure hardware acceleration is enabled in Android Studio AVD Manager. Use an x86_64 image, not ARM.

---

## Architecture Quick Reference

```
User taps a card
  → Riverpod provider reads from Drift (local SQLite)
  → FSRS algorithm computes next review (pure Dart, O(1))
  → Result written to card_memory_state (O(1) update)
  → Result appended to review_log (O(1) insert)
  → SyncEngine queues review_log row for push to Supabase
  → Next time online: SyncEngine pushes in background
  → User never waits for network
```

```
New country added
  → Contributor writes content/governments/{cc}/government.yaml
  → Opens pull request
  → CI runs validate_government.py (cycle detection, reachability, schema)
  → Maintainer reviews for accuracy and neutrality
  → Merges to main
  → CI runs seed_governments.py (hash diff: only changed rows written)
  → Country appears in app on next content pull
  → Zero app code changes required
```

---

## Useful Commands Reference

```bash
# Flutter
flutter run                              # Run app
flutter test                             # Run all tests
flutter analyze                          # Lint check
flutter build apk                        # Build Android APK
flutter build ios                        # Build iOS (macOS only)
flutter build web                        # Build web

# Drift code generation
dart run build_runner build --delete-conflicting-outputs

# Supabase
supabase start                           # Start local
supabase stop                            # Stop local
supabase db push                         # Apply migrations
supabase db reset                        # Reset to clean state (DELETES ALL DATA)

# Content pipeline
python3 scripts/validate_government.py content/governments/us/government.yaml
python3 scripts/validate_decks.py content/decks/us/executive/president.yaml
python3 scripts/seed_governments.py content/governments/
python3 scripts/seed_decks.py content/decks/
```
