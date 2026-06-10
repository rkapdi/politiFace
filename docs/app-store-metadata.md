# App Store Connect — Politiface metadata draft

Drop these strings directly into App Store Connect → Distribution →
Version Information. All character counts are below Apple's caps.

---

## App name (30 char max)

**Politiface**
_10 chars._

## Subtitle (30 char max)

**Know your government.**
_22 chars._ Alternates:
- "Civics, learned by face." (24)
- "Memorize the people in power." (29)
- "Politicians, learned by face." (29)

## Promotional text (170 char, editable any time after launch)

> The fastest way to learn the names, roles, and structure of the U.S.
> government. Daily rounds, a spaced-repetition memory engine, and a
> trivia gauntlet that bets your confidence.

_192 → trim to 170:_

> Learn the names, roles, and structure of the U.S. government — fast.
> Daily rounds, a spaced-repetition memory engine, and trivia that bets
> your confidence.

_168 chars._

## Description (4,000 char max)

```
Politiface teaches you who runs the country — by face.

WHAT YOU GET
• A daily round (5 face-cards + 10 confidence-scored trivia questions) tuned to your memory by the FSRS spaced-repetition algorithm
• An Atlas of every Cabinet secretary, Supreme Court Justice, and Congressional leader, browsable and searchable
• A Memory tab that visualizes which faces are crystallizing into long-term memory and which are about to slip
• An Endless mode for quick free-play between daily rounds
• A History tab so you can review every run you've ever finished

THE MEMORY ENGINE
Politiface uses Free Spaced Repetition Scheduler (FSRS) — the same algorithm behind Anki — to predict when you're about to forget a face and surface it before that happens. Each review tightens the schedule. The Memory Field on the Memory tab is a live visualization of that process.

THE CONFIDENCE SCORE
Daily Trivia doesn't just ask if you got the answer right. After each pick you lock in how sure you are: Guess, Pretty Sure, or 100%. Wrong + 100% costs you 10 points. Right + Guess earns you 5. At the end you get one of four archetypes — Civic Scholar, Lucky Guesser, Civic Bluffer, Humble Apprentice — based on your accuracy and your calibration.

YOUR DATA STAYS ON YOUR DEVICE
Politiface has no account system, no sign-up, no email field. Your progress, streak, and review history live in a local SQLite database. We collect no political affiliation, no voting history, no contact list. See our privacy policy for the full breakdown.

OPEN SOURCE
The app is MIT-licensed. Audit the code at github.com/rkapdi/politiFace.

WHAT'S COMING
v1.1 ships with cross-mode History, a Brain Strength indicator on the Memory tab, light/dark theme toggle, gender-aware distractor options, and tap-to-zoom on every politician portrait. Future versions add cross-device sync, more curricula (UK, Canada, India), and a paid pro layer.

REQUIREMENTS
• iPhone running iOS 14 or later
• No internet connection required after install
```

_~2,150 chars._

## Keywords (100 char max, comma-separated)

```
civics,government,politics,memorize,trivia,spaced repetition,uscis,naturalization,senate,cabinet
```
_99 chars._

## Category

- **Primary**: Education
- **Secondary**: Reference

(Avoid News/Magazines — too crowded and Apple is stricter on political
content there.)

## Age rating

- **Frequent/Intense Mature/Suggestive Themes**: None
- **Frequent/Intense Realistic Violence**: None
- **Profanity or Crude Humor**: **Infrequent/Mild** (because of the
  archetype names — Bluffer is fine but the 💩 emoji on the result
  card pushes you out of "None"). This lands the app at **9+** which is
  fine.
- **Political/Topical Issues**: **None** (factual civics, no political
  position taken)

## App Privacy ("data collected") questionnaire answers

Politiface is the rare app that gets to answer "No data collected" for
nearly everything. Specifically:

| Data type | Collected? | Notes |
|---|---|---|
| Contact info (name, email, phone) | **No** | We don't ask. |
| Health & fitness | **No** | — |
| Financial info | **No** | — |
| Location | **No** | — |
| Sensitive info (political affiliation, etc.) | **No** | We deliberately don't ask. |
| Contacts | **No** | — |
| User content (photos, audio, content created in-app) | **No** | Reviews stay on device. |
| Browsing history | **No** | — |
| Search history | **No** | — |
| Identifiers (device ID, user ID) | **No** | We don't track between sessions. |
| Purchases | **No** | No IAP in v1. |
| Usage data (app interactions, product interactions, crash data) | **Yes — crash data + diagnostics (Sentry), opt-in usage analytics** | Not linked to user, not used for tracking. |
| Diagnostics | **Yes — performance + crash logs** | Not linked to user. |

For the two "Yes" rows, mark:
- **Linked to user?** **No** — we have no user identity to link to.
- **Used for tracking?** **No** — we don't follow users across apps or
  sites.

That should keep the App Privacy "label" minimal: just "Diagnostics:
Crash data, Performance data" with the "not linked / not tracking" flags.

## Support URL

`https://rkapdi.github.io/politiFace/support`

(Point GitHub Pages at the `docs/` directory of the repo. The pages
render from `docs/support.md` automatically with the default Jekyll
theme.)

## Marketing URL (optional)

`https://github.com/rkapdi/politiFace`

(Can be the GitHub repo until you have a marketing site.)

## Privacy policy URL

`https://rkapdi.github.io/politiFace/privacy`

(Same GitHub Pages setup, sourced from `docs/privacy-policy.md`.)

## Copyright

`© 2026 Rissalat Kapdi`

## App Review notes (free-text field for the reviewer)

```
Politiface is a civics learning app. There is no login, no in-app purchase, and no political position taken by the app. All gameplay data is local to the device. Crash reports are sent anonymously to Sentry with personal info stripped (`sendDefaultPii: false`).

Suggested test path:
1. Tap "Play Today's Round" on Home → grade 5 cards → answer 10 trivia questions → see archetype reveal.
2. Tap "Are you a Civic Bluffer?" tile → standalone Daily Trivia.
3. Tap "Play forever" → Endless mode. Tap the share icon in the AppBar to verify the share sheet works. Tap "END RUN" to see the result screen.
4. Memory tab → tap the clock icon top-right → see History.
5. Settings (gear icon top-right of Home) → Appearance → toggle Dark to verify theme switch persists across kills.

No demo account needed — there are no accounts in the app.
```

## What to test (TestFlight free-text field)

```
v1.1 ships:
- Cross-mode history (Memory tab → clock icon top-right)
- Per-question review screens for Daily Trivia, Daily Round, and Endless runs
- Brain Strength indicator on the Memory tab
- Light / Dark / System theme toggle in Settings → Appearance
- Gender-aware distractors in trivia (no more "identify the senator" with cross-gender wrong options)
- Tap any politician portrait to zoom
- Endless mode share + End Run flow with a printable streak card
- Clickable chapter rows on the Home tab open a chapter info sheet

Please try every flow at least once. Watch for crashes, dark-mode contrast issues, and any place where text wraps or clips weirdly. Replies on the TestFlight feedback button land in App Store Connect → TestFlight → Feedback.
```

---

## Screenshot brief (you capture these from a release build)

Apple wants at minimum 3 screenshots at the **6.9" iPhone** size
(1320×2868). They accept the same images upscaled-or-downscaled across
other device sizes if you only have one set.

**Step 1: build in release mode** so the DEBUG ribbon doesn't ship.

```bash
cd app
PATH="/opt/homebrew/bin:$PATH" flutter run --release \
  -d <iphone-17-pro-max-simulator-udid>
```

(If you don't have iPhone 17 Pro Max simulator installed, get it from
Xcode → Settings → Components. iPhone 17 Pro at 6.3" also works but
you'll have to upload at the 6.7" slot.)

**Step 2: capture each screen below** with:

```bash
xcrun simctl io <udid> screenshot docs/app-store-screenshots/<name>.png
```

Required (8 screens — Apple's max is 10):

| # | Screen | How to reach |
|---|---|---|
| 01 | Home (dark mode) | App opens here. Confirm the chapter card and the TRIVIA / ENDLESS tiles are all visible. |
| 02 | Daily Trivia mid-question with reveal flash | Tap "Are you a Civic Bluffer?" → answer one question → tap a confidence chip → capture during the 750ms reveal hold so the green/red glow is visible. |
| 03 | Trivia result with Civic Scholar archetype | Finish a 10-question run with ~7+ correct + Pretty Sure on most. Or finish any run — what matters is the archetype reveal layout. |
| 04 | Atlas with portraits visible | Tap Atlas tab → scroll to LEGISLATIVE branch → capture with at least 4 face cards showing. |
| 05 | Memory tab Brain Strength hero | Tap Memory → capture so the 0–100 score ring + stage + memory field viz are all in frame. (Play a Daily Round first if you need a non-zero score.) |
| 06 | Daily Round cards phase (back) | Tap Play Today's Round → tap a card to reveal → capture showing the portrait + one-liner. |
| 07 | Settings → Appearance picker (light mode) | Settings (gear icon top-right of Home) → switch to light → capture so all 3 mode tiles are visible with LIGHT selected. |
| 08 | History screen | Memory tab → clock icon top-right → capture with at least 2 rows visible. |

For the App Store upload, drag all 8 into App Store Connect →
Distribution → 6.9" Display tab.

## Quick sanity checklist before hitting Submit

- [ ] All metadata fields above pasted in
- [ ] At least 3 iPhone 6.9" screenshots uploaded (Apple's current top-spec)
- [ ] 1024×1024 app icon uploaded (no transparency, no rounded corners)
- [ ] Privacy Policy URL resolves (test in incognito)
- [ ] Support URL resolves (test in incognito)
- [ ] Build 1.1.0 (2) attached to this version
- [ ] App Privacy questionnaire complete
- [ ] Age rating set to 9+ (or whatever the questionnaire lands you at)
- [ ] Export Compliance answered (uses standard iOS encryption — exempt)
- [ ] App Review notes filled
