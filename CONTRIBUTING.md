# Contributing to Politiface

Politiface is fully open source (MIT License). Contributions are welcome and appreciated.

**Scope note for V1:** the app currently supports the United States federal government
only. Multi-country support is a stated goal, but the app code is not there yet — the
government graph, curriculum, and seeding are US-specific. Until the code can honor it,
we are **not accepting new-country content PRs**; they would have nothing to plug into.
What we gladly accept today:

1. **US content fixes** — corrections to politicians, titles, portraits, curriculum text
2. **Code contributions** — bug fixes, tests, and features discussed in an issue first

---

## Path 1: US Content Fixes (No Programming Required)

The content is plain YAML:

- **Decks (people):** `app/assets/content/decks/*.yaml` — one file per institution
  (Presidency, Cabinet, Senate, ...). Each card has a name, title, party, portrait
  path, and source URL.
- **Curriculum:** `app/assets/content/curriculum/us_civics.yaml` — the six-chapter
  civics learning path.
- **Government structure:** `content/governments/us/government.yaml` — institutions
  and their relationships. This file is canonical; the app ships a byte-identical
  bundled copy at `app/assets/content/governments/us/government.yaml` (Flutter can
  only bundle files inside the app package). If you edit the canonical file, run
  `cp content/governments/us/government.yaml app/assets/content/governments/us/government.yaml`
  — CI fails the PR if the two differ.
- **Portraits:** `content/portraits/` (tracked for provenance) and
  `app/assets/portraits/` (bundled in the app), with `manifest.json` recording the
  Wikidata source of every image.

### Steps

1. Fork the repository.
2. Edit the relevant YAML file(s). Follow the format of neighboring entries exactly.
3. Every card **must** have a `source` field pointing to an official government
   website (e.g. `https://www.whitehouse.gov/administration/...`,
   `https://www.senate.gov/...`). This is non-negotiable for accuracy and neutrality.
4. Read the [Editorial Neutrality Guidelines](#editorial-neutrality-guidelines) below.
5. Open a pull request. CI validates the government YAML structurally
   (schema, unlock-graph cycles, map coordinates — see
   `.github/workflows/content-ci.yml`) and runs the app's content-pinning
   tests; a maintainer reviews for accuracy and neutrality before merging.

One important rule: **node IDs are forever.** Existing installs key their
unlock progress to node ids like `us-node-senate`; renaming an id orphans that
progress. The test suite pins the id set and will fail your PR if an id
changes — that's intentional, not a flaky test.

When a politician changes office (new Cabinet secretary, new Speaker), the fix is:
update the deck YAML entry, and if a new portrait is needed, run
`scripts/fetch_wikidata_portraits.py` and `scripts/wire_portraits.py` (or note it in
the PR and a maintainer will).

---

## Path 2: Code Contributions (Developers)

### Prerequisites

- Flutter SDK 3.22.x (the project is pinned to this; please don't upgrade it in a PR)
- Dart SDK ≥ 3.3.0

There is no backend and no `.env` to configure. The app is fully offline.

### Setup

```bash
# 1. Fork and clone the repo
git clone https://github.com/your-username/politiface.git
cd politiface/app

# 2. Install dependencies
flutter pub get

# 3. Run the tests (must pass before any code changes)
flutter test

# 4. Start the app (iOS simulator)
flutter run
```

Generated Drift code (`*.g.dart`) is committed. You only need
`dart run build_runner build --delete-conflicting-outputs` if you change database
tables or DAOs.

### Before submitting a PR

- [ ] All existing tests pass: `flutter test`
- [ ] No analyzer warnings or errors: `flutter analyze`
- [ ] New features have unit tests
- [ ] Database schema changes come with a migration **and** a migration test that
      proves user data (FSRS memory state, streaks, XP, history) survives the upgrade
- [ ] Changes to the FSRS algorithm or the practice-path policy in
      `card_review_repository.dart` are discussed in an issue first
- [ ] The PR description explains what changed and why

---

## Editorial Neutrality Guidelines

Politiface is built on trust. Any perception of political bias can destroy that trust
permanently. Every contributor is responsible for maintaining strict neutrality.

### The rules

**Identical structure for all parties.** Every card has the same fields in the same
format regardless of the politician's party.

**Official sources only.** Card content must be sourced from official government
websites, official party websites, or nonpartisan biographical sources. No newspaper
articles, no opinion pieces, no campaign materials.

**No controversy content.** Scandals, allegations, legal proceedings, and political
controversies are never included in card content. The one-liner describes their role,
not their reputation.

**Neutral language.** Describe what they do, not how you feel about it.

**Symmetry in selection.** If you include the RNC chair, include the DNC chair. If you
include a prominent former Republican president, include a prominent former Democratic
president.

**Photo consistency.** Use official government headshots for everyone. Not campaign
photos, not press photos, not photos chosen because they are flattering or unflattering.

### When in doubt

If you are unsure whether something is neutral, it probably is not. Ask in the PR
comments and a maintainer will help.

---

## Reporting a Security Vulnerability

Do not open a public GitHub issue for security vulnerabilities.

Email: security@politiface.io

We will respond within 48 hours.

---

## Analytics and Privacy

Politiface has **no analytics**. The only telemetry is crash reporting via Sentry, and
the app never collects which politicians you review, whether you got a card right or
wrong, or anything about your political preferences. The complete, verifiable
description is in [VERIFIED.md](VERIFIED.md) — keeping that document truthful is part
of every PR review.

---

## License

By contributing, you agree that your contributions will be licensed under the MIT
License ([LICENSE](LICENSE)).
