<p align="center">
  <img src="docs/assets/icon.png" width="112" alt="Politiface app icon">
</p>

<h1 align="center">Politiface</h1>

<p align="center">
  <b>Learn how the US government works, one short round a day.</b><br>
  Spaced-repetition civics, Florida Civic Literacy Exam (FCLE) practice, a cited civic reference, and live class sessions.
</p>

<p align="center">
  <a href="https://politiface.app"><img alt="Website" src="https://img.shields.io/badge/web-politiface.app-0b0b0d?logo=safari&logoColor=white"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/licence-MIT-blue"></a>
  <a href="https://github.com/rkapdi/politiFace/actions/workflows/flutter-ci.yml"><img alt="Flutter CI" src="https://github.com/rkapdi/politiFace/actions/workflows/flutter-ci.yml/badge.svg"></a>
  <a href="https://github.com/rkapdi/politiFace/actions/workflows/content-ci.yml"><img alt="Content CI" src="https://github.com/rkapdi/politiFace/actions/workflows/content-ci.yml/badge.svg"></a>
  <a href="https://github.com/rkapdi/politiFace/actions/workflows/db-ci.yml"><img alt="Database CI" src="https://github.com/rkapdi/politiFace/actions/workflows/db-ci.yml/badge.svg"></a>
  <img alt="Flutter 3.22" src="https://img.shields.io/badge/Flutter-3.22-02569B?logo=flutter&logoColor=white">
  <img alt="Platform: iOS" src="https://img.shields.io/badge/platform-iOS-lightgrey?logo=apple">
</p>

Open source under the MIT license so anyone can audit exactly what students see and what the app does with their data.
**The app never collects political affiliation or voting history.**

## What it does

- **Daily round.** Five flashcards plus a ten-question trivia set, about four minutes, scheduled with the FSRS-4.5 spaced-repetition algorithm so cards come back just before you would forget them.
- **FCLE practice.** A question bank mapped to the Florida Civic Literacy Exam objectives, with readiness tracking per objective.
- **Atlas.** A cited civic reference: government structure, people, founding documents, with primary sources.
- **Live class sessions.** Teachers run a session, students join with a code, and the teacher sees results in a web console.

## How it is built

| Layer | Stack |
| --- | --- |
| iOS app | Flutter, Riverpod, go_router, Drift (local SQLite, works offline) |
| Teacher console | React, TypeScript, Vite, served at [politiface.app/app](https://politiface.app/app/) |
| Backend | Supabase: Postgres with row-level security, RPCs, Edge Functions, SQL smoke tests |
| Content | Plain YAML in this repo, validated in CI and checksummed so the app re-seeds when it changes |
| Delivery | GitHub Actions for tests and scheduled data refresh, Codemagic for iOS builds |

Every pull request runs the Flutter tests and analyzer, validates the content files, and runs the database tests. Congressional and executive-order data refresh on a schedule through workflows in `.github/workflows`.

## Repository layout

| Path | What it is |
| --- | --- |
| `app/` | Flutter app (iOS). See [`app/README.md`](app/README.md). |
| `web/` | React + Vite web app served at politiface.app/app. See [`web/README.md`](web/README.md). |
| `supabase/` | Backend: Postgres migrations, row-level security, RPCs, Edge Functions, tests. See [`supabase/README.md`](supabase/README.md). |
| `content/` | Canonical content as YAML: government structure, people, Atlas, FCLE objectives and question bank. See [`content/questions/README.md`](content/questions/README.md). |
| `scripts/` | Content ingest, validation and data refresh scripts. |
| `docs/` | The public website (GitHub Pages), including the privacy policy and support pages. |

## Run it yourself

```bash
# iOS app (Flutter 3.22)
cd app && flutter pub get && flutter test

# Teacher console
cd web && npm install && npm run dev

# Database tests (needs a local Postgres)
bash supabase/tests/run_local.sh
```

Each folder's README has the details and the environment variables it needs.

## Privacy

The privacy policy is at [politiface.app/privacy-policy](https://politiface.app/privacy-policy/).
The app never collects political affiliation or voting history.

## Contributing

Corrections to civic content are welcome: open an issue with the fix and a primary
source.

## License

MIT. See [LICENSE](LICENSE).
