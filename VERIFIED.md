# VERIFIED: What This App Sends

This document describes every byte of telemetry Politiface transmits. It is kept in
lockstep with the code; if the code and this document ever disagree, that is a bug —
please report it.

## The short version

**Politiface has no analytics.** No events, no user IDs, no usage tracking, no
third-party analytics SDK. There is no analytics code in this repository.

The only telemetry is **crash reporting via Sentry**, and the only other network
traffic is **Wikipedia/Wikidata bio fetches** that you trigger by opening a
politician's detail screen.

## Crash reporting (Sentry)

- Initialized in [`app/lib/main.dart`](app/lib/main.dart). If the build contains no
  Sentry DSN, the SDK no-ops and **nothing is ever sent** — this is the case for any
  build you compile yourself from this repo.
- Official TestFlight/App Store builds inject a DSN at build time
  (see [`codemagic.yaml`](codemagic.yaml)) so we can see crashes.
- `sendDefaultPii` is `false`: no names, emails, or personal info are attached.
- Performance traces are sampled at 10%.
- Crash reports contain stack traces and device/OS class information — never which
  cards you reviewed, what you answered, or anything about your political interests.

**Known gap, stated honestly:** crash reporting in official builds is currently
enabled by default, not gated behind an in-app consent toggle. An explicit opt-in/out
switch is planned before public launch; this document will be updated when it ships.

## Wikipedia bio fetches

When you open a politician's detail screen, the app fetches a short bio summary from
the public Wikipedia/Wikidata APIs (`app/lib/features/atlas/data/wikipedia_bio_service.dart`)
and caches it locally. This is a plain content request to Wikimedia servers, not
telemetry to us — we operate no server and cannot see it. It reveals to Wikimedia only
that some IP requested a public article summary.

## What is NEVER sent, to anyone

- Which politician cards you review
- Which cards you get right or wrong
- Your streaks, XP, scores, or progress
- Your political preferences, affiliations, or leanings
- Your name, email, location, or any personally identifiable information

None of this *can* be sent: all user data lives in a local SQLite database on your
device, and the app has no backend.

## Verify it yourself

1. Clone this repository.
2. Search `app/lib/` for network code: the only HTTP client usage is in
   `wikipedia_bio_service.dart`, and the only SDK that transmits anything is
   `sentry_flutter` in `main.dart`.
3. Search for `posthog`, `firebase`, `analytics` — there are no hits in `app/lib/`.
4. Build the app yourself (no DSN) and observe zero telemetry traffic.

There is no private analytics layer. What you can read here is everything.

---

*Last updated: June 2026*
