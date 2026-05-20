# Politiface

**Global political literacy. Open source. No tracking.**

Politiface is a mobile-first app that uses spaced repetition and gamification to help you learn politicians, government structures, and civics. Think Duolingo meets Anki, but for political knowledge.

We open sourced this because a political literacy app has no business knowing your political preferences. Read the code yourself.

---

## Why Open Source?

A privacy policy says we don't track your political interests. An open source codebase **proves** it.

The [complete list of analytics events](VERIFIED.md) we send is published in this repository. We never collect which politicians you review, which cards you get right or wrong, or anything that could imply your political leanings.

---

## Features

- **Government map** — progress through a visual representation of each country's government structure, unlocking institutions and people as you go
- **FSRS-4.5 spaced repetition** — empirically superior to SM-2, trained on 1.7 billion reviews
- **Daily Challenge** — same 5 cards for everyone worldwide, shareable emoji result grid
- **Offline-first** — works on the subway, syncs when connected
- **Multiple card types** — face recognition, role identification, concept comprehension, sequence ordering
- **Streaks, XP, leagues** — the gamification layer that makes daily sessions stick

---

## Countries

| Country | Status | Maintainer |
|---|---|---|
| 🇺🇸 United States | ✅ Active | Core team |
| More coming | | [Contribute yours →](CONTRIBUTING.md) |

---

## Tech Stack

- **Flutter** — single codebase for iOS, Android, and Web
- **Drift** — local SQLite, offline-first source of truth
- **Supabase** — remote Postgres, auth, storage
- **FSRS-4.5** — spaced repetition algorithm (pure Dart)
- **Riverpod** — state management

---

## Self-Hosting

Run your own instance:

```bash
# Clone the repo
git clone https://github.com/politiface/politiface.git
cd politiface

# Start local Supabase
supabase init && supabase start

# Apply schema
supabase db push

# Seed US content
pip install pyyaml supabase
python scripts/seed_governments.py content/governments/
python scripts/seed_decks.py content/decks/

# Run the app
cd app
cp .env.example .env
# Edit .env with your local Supabase URL and anon key
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Or use Docker:
```bash
docker-compose up
```

---

## Contributing

Adding politicians from your country requires no programming knowledge — just YAML files. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

---

## Analytics

We collect minimal, opt-in analytics. Every event we track is listed in [VERIFIED.md](VERIFIED.md).

---

## License

MIT — see [LICENSE](LICENSE)
