# VERIFIED: Complete Analytics Event List

This document lists every analytics event Politiface sends. Nothing else is sent.

Analytics are **opt-in only**. If you did not explicitly consent during onboarding, nothing is sent.

---

## Events We Send

| Event | Payload | Purpose |
|---|---|---|
| `session_started` | `deck_id`, `card_count` | Know how many sessions are started per deck |
| `session_completed` | `cards_reviewed`, `correct_pct`, `duration_ms` | Measure session completion and difficulty |
| `streak_extended` | `streak_count` | Track streak growth |
| `streak_broken` | `streak_count` | Understand where streaks end |
| `challenge_completed` | `score` (0-5), `shared` (boolean) | Measure Daily Challenge engagement |
| `module_completed` | `node_external_id` (e.g. `us-node-senate`) | Track curriculum progression |
| `deck_unlocked` | `deck_external_id` | Track content discovery |
| `app_opened` | `days_since_install` | Basic retention measurement |

## What We NEVER Send

- Which specific politician cards you reviewed
- Which cards you got right or wrong
- Your political preferences, affiliations, or leanings
- Any information that could identify your political views
- Your name, email, or any personally identifiable information (events are keyed to an anonymous UUID only)
- Your location
- Your device model

## Verification

You can verify this yourself:

1. Clone this repository
2. Search for `PostHog` or `analytics` in `app/lib/`
3. Every event capture is in `app/lib/core/analytics/analytics_service.dart`
4. That file is the single source of truth for what we send

The analytics implementation is in the open source codebase. There is no private analytics layer.

---

*Last updated: May 2026*
