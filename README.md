# Politiface

**Learn how the US government actually works. Fully offline. Open source. No tracking.**

Politiface is an iOS app that uses spaced repetition and gamification to help you learn
the people and structure of the United States federal government. Think Duolingo meets
Anki, but for civic knowledge.

We open sourced this because a political literacy app has no business knowing your
political preferences. Read the code yourself.

---

## What the app is (V1)

- **iOS only.** Android and web are not supported in V1.
- **Fully offline.** All content ships inside the app; all of your progress lives in a
  local SQLite database on your device. There are no accounts, no cloud sync, and no
  server of ours that the app talks to.
- **No analytics.** The app collects no analytics events of any kind. The only telemetry
  is anonymous crash reporting via Sentry — see [VERIFIED.md](VERIFIED.md) for exactly
  what that means and how to verify it.
- **Open source under MIT** — see [LICENSE](LICENSE).

## Features

- **FSRS-4.5 spaced repetition** — the published FSRS-4.5 algorithm in pure Dart, using
  the default weights trained on 1.7 billion reviews. Same-day repeats are treated as
  practice so they never corrupt your memory schedule.
- **Daily chapter rounds** — a short daily session of flashcards plus a trivia quiz,
  tied to a six-chapter US civics curriculum.
- **Atlas** — a browsable, searchable directory of the politicians in the app, with
  mastery rings and on-demand Wikipedia bios.
- **Endless and Trivia modes** — keep going past the daily round, share your results
  as an emoji grid.
- **Streaks, XP, and mastery tiers** — the gamification layer that makes daily
  sessions stick.
- **History** — review every past run.

The only network requests the app makes are: fetching politician bio summaries from
Wikipedia/Wikidata when you open a detail screen (cached locally afterward), and crash
reports if Sentry is enabled in the build. Everything else works in airplane mode.

## Content

V1 covers the United States federal government: the Presidency, Cabinet, Executive
Office, Congress, and the Supreme Court — 7 decks, 46 politicians with sourced
portraits, and a 6-chapter civics curriculum. All content is plain YAML under
[`content/`](content/) and [`app/assets/content/`](app/assets/content/), validated in CI.

Support for additional countries is a goal, but the app code does not support it yet —
see [CONTRIBUTING.md](CONTRIBUTING.md) for what you can contribute today.

## Tech stack

- **Flutter** (3.22, iOS target)
- **Drift** — local SQLite, the single source of truth for user data
- **FSRS-4.5** — spaced repetition scheduling (pure Dart, no dependencies)
- **Riverpod** — state management
- **go_router** — navigation

## Running it yourself

```bash
git clone https://github.com/politiface/politiface.git
cd politiface/app
flutter pub get
flutter run
```

That's it — there is no backend to set up. The app seeds its database from bundled YAML
on first launch.

To run the tests:

```bash
cd app
flutter test
flutter analyze
```

## Contributing

Content fixes (US politician updates, curriculum corrections) require no programming —
just YAML edits. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Privacy

The app sends no analytics. The complete, verifiable description of the app's telemetry
(crash reporting only) is in [VERIFIED.md](VERIFIED.md). The privacy policy is at
[docs/privacy-policy.md](docs/privacy-policy.md).

## License

MIT — see [LICENSE](LICENSE).
