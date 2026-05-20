# GIT AND FLUTTER SETUP — COMPLETE WALKTHROUGH
# Run these commands in order. Every step must succeed before the next.

# ══════════════════════════════════════════════════════════════════════════════
# PART 1: FLUTTER INSTALLATION
# ══════════════════════════════════════════════════════════════════════════════

# ── Step 1.1: Install FVM (Flutter Version Manager) ──────────────────────────
# FVM lets you pin the Flutter version per project.
# Never install Flutter directly — FVM gives you control.

brew install fvm

# ── Step 1.2: Install Flutter 3.22.0 via FVM ─────────────────────────────────
fvm install 3.22.0
fvm global 3.22.0

# Verify
flutter --version
# Expected: Flutter 3.22.0 • channel stable

# ── Step 1.3: Run Flutter Doctor ──────────────────────────────────────────────
flutter doctor

# Fix everything it reports. Common fixes:
#
# [✗] Android toolchain:
#   brew install --cask android-studio
#   Open Android Studio → SDK Manager → Install Android SDK
#   Then: flutter doctor --android-licenses (accept all)
#
# [✗] Xcode:
#   Install from Mac App Store (takes ~30 min)
#   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
#   sudo xcodebuild -runFirstLaunch
#
# [✗] VS Code Flutter extension:
#   In VS Code: Cmd+Shift+P → Extensions: Install Extensions → "Flutter"

# ── Step 1.4: Install VS Code Extensions ─────────────────────────────────────
# Install all of these:
#   dart-code.dart-code        (Dart language support)
#   dart-code.flutter          (Flutter support)
#   redhat.vscode-yaml         (YAML editing for content files)
#   ms-python.python           (Python for scripts)
#   eamodio.gitlens            (Git history in editor)
#   usernamehw.errorlens       (Inline error display)

# ── Step 1.5: Create iOS Simulator ───────────────────────────────────────────
# Open Simulator from Applications or:
open -a Simulator

# In Simulator: File → New Simulator → iPhone 15 Pro → iOS 17.x
# Name it "Politiface Dev"

# ── Step 1.6: Create Android Emulator ────────────────────────────────────────
# Open Android Studio → Device Manager → Create Device
# Choose: Pixel 7 Pro → API 34 (Android 14) → x86_64 image
# IMPORTANT: Use x86_64, not ARM — 10x faster on Intel/AMD Macs
# Name it "Politiface Dev"

# ══════════════════════════════════════════════════════════════════════════════
# PART 2: GIT SETUP
# ══════════════════════════════════════════════════════════════════════════════

# ── Step 2.1: Configure Git identity ─────────────────────────────────────────
git config --global user.name "Rissalat Kapdi"
git config --global user.email "your@email.com"

# Better log formatting
git config --global log.oneline true
git config --global alias.lg "log --oneline --graph --decorate --all"

# Default branch name
git config --global init.defaultBranch main

# ── Step 2.2: Generate SSH key for GitHub ────────────────────────────────────
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_github
# Press Enter for passphrase (or set one for extra security)

# Add to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_github

# Copy public key to clipboard
pbcopy < ~/.ssh/id_ed25519_github.pub

# Add to GitHub:
# github.com → Settings → SSH and GPG keys → New SSH key
# Paste the key. Title: "MacBook Pro - Politiface Dev"

# Test connection
ssh -T git@github.com
# Expected: Hi Rissalat! You've successfully authenticated...

# ── Step 2.3: Create GitHub repository ───────────────────────────────────────
# 1. Go to github.com/new
# 2. Repository name: politiface
# 3. Description: Global political literacy platform. Open source.
# 4. Visibility: PUBLIC (open source — this is intentional)
# 5. Initialize with: NOTHING (we'll push from local)
# 6. Click Create repository

# ── Step 2.4: Initialize local repo ──────────────────────────────────────────
# Navigate to your extracted starter kit
cd /path/to/politiface

# Initialize git
git init

# Add remote (replace with your GitHub username)
git remote add origin git@github.com:YOUR_USERNAME/politiface.git

# Verify remote
git remote -v
# Expected:
# origin  git@github.com:YOUR_USERNAME/politiface.git (fetch)
# origin  git@github.com:YOUR_USERNAME/politiface.git (push)

# ── Step 2.5: Create branch structure ────────────────────────────────────────
# Branch strategy:
#   main    → production. Protected. Triggers Codemagic deploy.
#   dev     → active development. PRs merge here first.
#   feature/* → individual features. Branch from dev, PR to dev.

# We're on main by default (from git init)
# Create dev branch
git checkout -b dev

# ── Step 2.6: First commit ────────────────────────────────────────────────────
# Stage everything
git add .

# Verify what you're committing (no .env, no secrets)
git status
# Should NOT see: .env, *.jks, *.keystore, *.p12, google-services.json

git commit -m "feat: initial project structure

- Flutter app with Drift + Riverpod + Supabase
- FSRS-4.5 algorithm with full unit test suite
- Offline-first sync engine with priority queue
- LRU cache and min-heap session queue
- US government graph YAML
- Supabase schema with hash partitioning and RLS
- GitHub Actions CI pipeline
- Codemagic deployment pipeline
- Open source documentation (README, CONTRIBUTING, VERIFIED)"

# Push dev branch
git push -u origin dev

# Switch to main and push
git checkout -b main
git push -u origin main

# Set main as default branch on GitHub:
# repo → Settings → Branches → Default branch → main

# ══════════════════════════════════════════════════════════════════════════════
# PART 3: GITHUB BRANCH PROTECTION RULES
# ══════════════════════════════════════════════════════════════════════════════

# Set these up in: GitHub → repo → Settings → Branches → Add branch ruleset

# ── main branch protection ────────────────────────────────────────────────────
# Branch name pattern: main
# Settings:
#   [x] Require a pull request before merging
#       Required approvals: 1
#   [x] Require status checks to pass before merging
#       Required checks:
#         - "Test + Lint" (from flutter-ci.yml)
#         - "Validate Government YAMLs" (from content-pipeline.yml)
#         - "Validate Deck YAMLs" (from content-pipeline.yml)
#   [x] Require branches to be up to date before merging
#   [x] Do not allow bypassing the above settings
#   [ ] Allow force pushes (leave unchecked)
#   [ ] Allow deletions (leave unchecked)

# ── dev branch protection ─────────────────────────────────────────────────────
# Branch name pattern: dev
# Settings:
#   [x] Require status checks to pass before merging
#       Required checks:
#         - "Test + Lint"
#   [x] Require branches to be up to date before merging

# ── Content directory: require 2 reviewers ───────────────────────────────────
# GitHub → repo → Settings → Code owners
# Create file: .github/CODEOWNERS

echo "# Content changes require Dawood's review
content/ @dawood-github-username @rissalat-github-username" > .github/CODEOWNERS

git add .github/CODEOWNERS
git commit -m "chore: add CODEOWNERS for content review"
git push

# ══════════════════════════════════════════════════════════════════════════════
# PART 4: SUPABASE PROJECT SETUP
# ══════════════════════════════════════════════════════════════════════════════

# ── Step 4.1: Create Supabase project ────────────────────────────────────────
# 1. supabase.com → New project
# 2. Organization: your org (or create one)
# 3. Name: politiface-production
# 4. Database password: generate a strong one, SAVE IT SOMEWHERE SAFE
# 5. Region: US East (closest to your US user base)
# 6. Pricing: Free tier is fine for development

# ── Step 4.2: Install Supabase CLI and link project ──────────────────────────
brew install supabase/tap/supabase

# Login
supabase login
# Opens browser → authorize

# Link to your project (get project ref from Supabase dashboard URL)
# URL format: https://supabase.com/dashboard/project/YOUR-PROJECT-REF
supabase link --project-ref YOUR-PROJECT-REF

# ── Step 4.3: Apply the migration ────────────────────────────────────────────
supabase db push
# This runs supabase/migrations/001_initial.sql on your remote project
# Verify in: Supabase Dashboard → Table Editor — all tables should appear

# ── Step 4.4: Get your API keys ──────────────────────────────────────────────
# Supabase Dashboard → Project Settings → API
# Copy:
#   Project URL → SUPABASE_URL
#   anon public → SUPABASE_ANON_KEY
#   service_role → SUPABASE_SERVICE_KEY (for CI/CD scripts only — never in app)

# ── Step 4.5: Set up local Supabase for dev ───────────────────────────────────
supabase start
# Outputs local credentials — use these in app/.env for local development

# ══════════════════════════════════════════════════════════════════════════════
# PART 5: FLUTTER APP SETUP
# ══════════════════════════════════════════════════════════════════════════════

cd app

# ── Step 5.1: Set up .env ─────────────────────────────────────────────────────
cp .env.example .env

# Edit .env with your LOCAL Supabase credentials (from supabase start output):
# SUPABASE_URL=http://localhost:54321
# SUPABASE_ANON_KEY=<local-anon-key>
# POSTHOG_API_KEY=placeholder        (set up PostHog account later)
# POSTHOG_HOST=https://app.posthog.com
# SENTRY_DSN=placeholder             (set up Sentry account later)

# ── Step 5.2: Install dependencies ───────────────────────────────────────────
flutter pub get

# ── Step 5.3: Generate Drift + Riverpod code ─────────────────────────────────
dart run build_runner build --delete-conflicting-outputs

# This generates:
#   lib/core/database/drift/app_database.g.dart  (Drift queries)
# You need to run this every time you:
#   - Add or change a Drift table
#   - Add or change a Riverpod provider with @riverpod annotation

# ── Step 5.4: Run tests ───────────────────────────────────────────────────────
flutter test test/
# All tests must pass.

flutter test test/features/session/domain/fsrs_algorithm_test.dart -v
# FSRS tests specifically — watch for any failures.

# ── Step 5.5: Run the app ─────────────────────────────────────────────────────
flutter devices
# Lists available simulators and emulators

flutter run -d "iPhone 15 Pro"     # iOS
flutter run -d "Pixel_7_Pro_API_34"  # Android (device name from flutter devices)
flutter run -d chrome               # Web

# ══════════════════════════════════════════════════════════════════════════════
# PART 6: GITHUB ACTIONS SECRETS
# ══════════════════════════════════════════════════════════════════════════════

# GitHub → repo → Settings → Secrets and variables → Actions → New repository secret

# Add these secrets:
#
#   SUPABASE_URL           → your production Supabase URL
#   SUPABASE_SERVICE_KEY   → your Supabase service_role key (NOT anon key)
#   CLOUDFLARE_ZONE_ID     → from Cloudflare dashboard (set up later)
#   CLOUDFLARE_API_TOKEN   → from Cloudflare dashboard (set up later)

# ══════════════════════════════════════════════════════════════════════════════
# PART 7: CODEMAGIC SETUP
# ══════════════════════════════════════════════════════════════════════════════

# ── Step 7.1: Create Codemagic account ───────────────────────────────────────
# codemagic.io → Sign up with GitHub
# Connect your GitHub account
# Find the politiface repo → Start new build (to verify connection)

# ── Step 7.2: Create environment variable group ───────────────────────────────
# Codemagic → Team → Global variables and secrets → Create group
# Group name: politiface-secrets
#
# Add these variables:
#   SUPABASE_URL              (non-secret)
#   SUPABASE_ANON_KEY         (secret)
#   POSTHOG_API_KEY           (secret)
#   POSTHOG_HOST              (non-secret)
#   SENTRY_DSN                (secret)
#   NETLIFY_AUTH_TOKEN        (secret — get from netlify.com → User settings → PAT)
#   NETLIFY_SITE_ID           (non-secret — from netlify.com → Site settings)

# ── Step 7.3: iOS signing (App Store Connect) ─────────────────────────────────
# Prerequisites:
#   - Apple Developer account ($99/year) enrolled in Apple Developer Program
#   - App created in App Store Connect: appstoreconnect.apple.com
#   - Bundle ID registered: io.politiface.app

# In Codemagic → Team → Integrations → Apple Developer Portal → Connect
# Then: Code signing identities → Distribution certificate → Add
# Then: Provisioning profiles → Add → App Store profile for io.politiface.app

# Create App Store Connect API key:
# appstoreconnect.apple.com → Users and Access → Keys → Generate API Key
# Role: App Manager
# Save: Key ID, Issuer ID, .p8 file (download once — can't re-download)
#
# Add to Codemagic env group:
#   APP_STORE_CONNECT_ISSUER_ID        (from Keys page)
#   APP_STORE_CONNECT_KEY_IDENTIFIER   (Key ID)
#   APP_STORE_CONNECT_PRIVATE_KEY      (contents of .p8 file)
#   CERTIFICATE_PRIVATE_KEY            (your distribution cert private key)

# ── Step 7.4: Android signing ─────────────────────────────────────────────────
# Create upload keystore (do this ONCE, back it up permanently):
keytool -genkey -v \
  -keystore ~/politiface-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias politiface-upload \
  -dname "CN=Politiface, O=Politiface, C=CA"
# Store the passwords somewhere safe (1Password, etc.)
# BACK UP THIS FILE. If you lose it, you cannot update your app on Play Store.

# Base64 encode the keystore
base64 -i ~/politiface-upload.jks | pbcopy
# Paste the output as FCI_KEYSTORE in Codemagic env group

# Add to Codemagic env group:
#   FCI_KEYSTORE           (base64 encoded .jks file)
#   FCI_KEY_ALIAS          (politiface-upload)
#   FCI_KEY_PASSWORD       (your key password)
#   FCI_KEYSTORE_PASSWORD  (your keystore password)

# ── Step 7.5: Google Play setup ───────────────────────────────────────────────
# 1. Create app in Google Play Console: play.google.com/console
#    Package name: io.politiface.app
# 2. Create service account for Codemagic:
#    Google Cloud Console → IAM → Service Accounts → Create
#    Role: Service Account User
#    Download JSON key
#    In Play Console → Setup → API access → Link service account
#    Grant permissions: Release Manager
# 3. Add JSON key contents as GCLOUD_SERVICE_ACCOUNT_CREDENTIALS in Codemagic

# ── Step 7.6: Netlify setup ───────────────────────────────────────────────────
# netlify.com → Add new site → Import an existing project
# At first: deploy manually, then Codemagic takes over
# Site settings → General → Site information → Copy Site ID → NETLIFY_SITE_ID
# User settings → Personal access tokens → New token → NETLIFY_AUTH_TOKEN

# ══════════════════════════════════════════════════════════════════════════════
# PART 8: SEED INITIAL CONTENT
# ══════════════════════════════════════════════════════════════════════════════

# From project root:
pip3 install pyyaml supabase

export SUPABASE_URL="https://your-project-ref.supabase.co"
export SUPABASE_SERVICE_KEY="your-service-role-key"

# Validate the US government YAML first
python3 scripts/validate_government.py content/governments/us/government.yaml

# Seed it
python3 scripts/seed_governments.py content/governments/

# Verify in Supabase Studio: Table Editor → gov_nodes
# Should see us-node-president, us-node-senate, etc.

# ══════════════════════════════════════════════════════════════════════════════
# PART 9: VERIFY THE FULL PIPELINE
# ══════════════════════════════════════════════════════════════════════════════

# 1. Create a test branch
git checkout dev
git checkout -b feature/test-pipeline

# 2. Make a trivial change
echo "# test" >> README.md
git add README.md
git commit -m "test: verify CI pipeline"

# 3. Push and open a PR to dev
git push -u origin feature/test-pipeline
# GitHub → Open pull request → base: dev

# 4. Watch GitHub Actions run:
#    - "Flutter CI / Test + Lint" — should pass in ~3 minutes
#    - "Validate Government YAMLs" — should pass immediately
#    - "Security Audit" — runs separately on schedule

# 5. Merge the PR to dev

# 6. Open another PR: dev → main
# Watch the same checks run again
# Merge to main

# 7. Watch Codemagic trigger:
#    - iOS build → TestFlight
#    - Android build → Play Store internal track
#    - Web build → Netlify
# First build takes ~20 minutes. Subsequent builds ~10 minutes (caching).

# ══════════════════════════════════════════════════════════════════════════════
# DAILY WORKFLOW (once everything is set up)
# ══════════════════════════════════════════════════════════════════════════════

# Start a feature:
git checkout dev
git pull origin dev
git checkout -b feature/map-renderer

# Work on the feature...

# Before committing:
cd app
flutter test                                          # must pass
flutter analyze                                       # must pass
dart run build_runner build --delete-conflicting-outputs  # if tables/providers changed

# Commit:
git add .
git commit -m "feat: implement government map node renderer"

# Push and open PR to dev:
git push -u origin feature/map-renderer
# Open PR on GitHub → base: dev → wait for CI → merge

# When dev is stable and ready to release:
# Open PR: dev → main → CI runs → Codemagic deploys to all three platforms

# ══════════════════════════════════════════════════════════════════════════════
# QUICK REFERENCE
# ══════════════════════════════════════════════════════════════════════════════

# Run tests:           flutter test
# Run FSRS tests:      flutter test test/features/session/domain/ -v
# Lint:                flutter analyze
# Generate code:       dart run build_runner build --delete-conflicting-outputs
# Run iOS:             flutter run -d "iPhone 15 Pro"
# Run Android:         flutter run -d emulator-5554
# Run web:             flutter run -d chrome
# Build web:           flutter build web --release
# Start local Supabase:supabase start
# Apply DB migration:  supabase db push
# Seed content:        python3 scripts/seed_governments.py content/governments/
# Validate YAML:       python3 scripts/validate_government.py content/governments/us/government.yaml
# Git log:             git lg   (alias set in step 2.1)
# New feature branch:  git checkout dev && git pull && git checkout -b feature/your-feature
