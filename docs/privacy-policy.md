---
title: Privacy Policy
permalink: /privacy-policy/
---

# Politiface — Privacy Policy

_Last updated: June 11, 2026_

Politiface is built local-first. Your gameplay, mastery progress, streak,
and review history live on your device only. We don't run an account
system, we don't collect personal information, and we don't sell data.

This document explains what stays on your phone, what is sent to third
parties, and the choices you control.

## What we collect

**Nothing identifies you to us.** Politiface does not ask for an email,
phone number, name, or any account. We have no server that holds your
gameplay.

The app stores the following **on your device only**, in a local SQLite
database (Drift):

- Cards you've reviewed and their FSRS memory state (stability,
  difficulty, retrievability).
- Trivia answers, daily round grades, and endless run history.
- Your streak, XP, and chapter progress.
- App preferences (theme mode, notification toggle, crash-report consent).

If you uninstall the app, all of this is deleted.

## What is sent to third parties

### Sentry (crash reporting — opt-in, off by default)

Crash reporting is **off until you turn it on** in
**Settings → Privacy → Crash reports**. If you never touch the toggle,
the Sentry SDK is never even initialized and nothing is sent, ever.

If you opt in, then when the app crashes or hits an unexpected error a
stack trace is sent to [Sentry](https://sentry.io) so we can fix bugs.
We have explicitly configured Sentry to **never attach personal
information** (`sendDefaultPii: false`). The report contains the error
message, the source line, and the software stack — not who you are.
You can opt back out at any time with the same toggle (takes effect on
the next launch).

The app has **no usage analytics of any kind** — no events, no
identifiers, no analytics SDK. See
[VERIFIED.md](https://github.com/rkapdi/politiFace/blob/main/VERIFIED.md)
for the verifiable, code-level description.

### Wikimedia (Wikidata + Wikipedia)

Politician portraits ship inside the app — they are not downloaded.
When you open a politician's detail screen, the app fetches a short
biographical summary from Wikipedia (cached on your device afterward).
These requests contain the politician's identifier — never anything
about you. They follow Wikimedia's own privacy policy, and the app
works fully offline without them.

### Apple (App Store + iOS)

Apple operates TestFlight, the App Store, and iOS. When you install or
update Politiface, Apple sees that. We don't get device-specific
identifiers from Apple beyond what every iOS app receives by default.

## What is NOT collected

- ❌ Your name, email, phone number, address
- ❌ Your political affiliation, voting history, or party
- ❌ Your contact list, photos, microphone, camera, or location
- ❌ Browsing history outside the app
- ❌ Cross-app tracking identifiers (we don't use IDFA)

## Children

Politiface is rated 9+ on the App Store. We don't knowingly collect
information from children under 13. If you believe a child has provided
personal information to us, contact us and we'll delete it — though
practically there's nothing to delete because we have no account
system.

## Your choices

- **Crash reports**: opt in or out at any time via
  Settings → Privacy → Crash reports (off by default).
- **Notification reminders**: opt in or out via
  Settings → Notifications → Daily review reminder, or in
  iOS Settings → Notifications → Politiface.
- **Reset progress**: wipes all local data via
  Settings → Danger zone → Reset progress.
- **Uninstall**: removes all local data.

## Open source

Politiface is open source under MIT license. You can audit exactly what
the app does at [github.com/rkapdi/politiFace](https://github.com/rkapdi/politiFace).

## Contact

Questions about privacy? Email **thedeclanmercer@gmail.com**.

## Changes to this policy

If we change what we collect — for example, when we eventually add user
accounts for cross-device sync — we'll update this page, bump the
"Last updated" date, and notify users via the app before the change
takes effect.
