# Accessibility Conformance Report scaffold (VPAT 2.5, WCAG edition)

Procurement deliverable for public institutions (DOJ 2024 ADA Title II
rule; WCAG 2.1 AA is the target). Levels: Supports, Partially Supports,
Does Not Support, Not Applicable.

**Product:** Politiface iOS app, version 1.1.0 (V2 branch)
**Report status:** DRAFT. Code-level audit completed 2026-07-04 (contrast
measured programmatically, semantics reviewed and fixed in source). Rows
marked "pending device pass" still need the on-device VoiceOver, Dynamic
Type, and Switch Control walkthrough before this report is shared
externally.
**Evaluation methods so far:** WCAG relative-luminance contrast
computation of every palette text pair in light and dark themes; source
audit of semantics (labels, roles, selected states, merged nodes, status
announcements); widget tests for overflow at share-card and screen sizes.

## Contrast audit record (2026-07-04)

Measured, then fixed in `editorial_theme.dart`:

| Pair | Before | After | Notes |
|---|---|---|---|
| ink on paper (body text, light) | 15.38:1 | unchanged | Passes |
| inkSubdued on paper (secondary, light) | 5.86:1 | unchanged | Passes |
| actionRed as text on paper | 4.49:1 FAIL | 5.23:1 | Red darkened 0xFFD6242C -> 0xFFC41E25 |
| actionRed as text, dark theme | 3.78:1 FAIL | 6.32:1 | New dark sibling 0xFFEE6A70; brandRed now brightness-aware |
| ochre as text on paper | 2.15:1 FAIL | 5.14:1 | New text-safe `ochreDeep` 0xFF7E6128 + `brandOchreText`; leaderboard ranks, class tile, chapter status switched |
| civicGreen on paper / dark | 5.31 / 6.86 | unchanged | Passes both modes |
| civicNavy on paper / dark | 12.54 / 6.35 | unchanged | Passes both modes |
| white on actionRed (buttons) | 5.06:1 | 5.90:1 | Improved by the red darkening |
| paper-inverted on ink-inverted (dark body) | 16.94:1 | unchanged | Passes |

Remaining contrast work items: legacy ochre-as-text usages predating this
audit (round reveal/briefing phases, atlas branch sheet, first-run tour,
trivia confidence colors) need the same `brandOchreText` treatment; card
hairline borders (1.34:1) are decorative but selected-state borders should
be re-checked against 1.4.11 on device.

## Table 1: Success criteria, Level A

| Criterion | Conformance | Remarks |
|---|---|---|
| 1.1.1 Non-text Content | Partially Supports | New FCLE/leaderboard icons ride merged text nodes; legacy politician portraits and the memory orbital field still need labels (work item) |
| 1.3.1 Info and Relationships | Partially Supports | List rows merged into single semantic nodes (readiness, leaderboard, domain bars); legacy screens pending device pass |
| 1.3.2 Meaningful Sequence | Partially Supports | Linear ListView layouts; device pass pending |
| 1.3.3 Sensory Characteristics | Supports | Correct/incorrect uses icon + color + text + announcement, never color alone |
| 1.4.1 Use of Color | Supports | Readiness and domain bars pair color with percentage/fraction text |
| 1.4.2 Audio Control | Not Applicable | No audio |
| 2.1.1 Keyboard | Partially Supports | Standard Flutter focus traversal; Switch Control pass pending |
| 2.1.2 No Keyboard Trap | Partially Supports | No custom focus traps in source; device pass pending |
| 2.2.1 Timing Adjustable | Supports | No time limits anywhere, including the mock (deliberate) |
| 2.2.2 Pause, Stop, Hide | Partially Supports | Confetti/animate effects are short and non-looping; verify with Reduce Motion on device |
| 2.3.1 Three Flashes | Supports | No flashing content |
| 2.4.1 Bypass Blocks | Not Applicable | Native app |
| 2.4.2 Page Titled | Supports | Every screen has an AppBar title; mock titles announce progress (Question N of 80) |
| 2.4.3 Focus Order | Partially Supports | Visual order = widget order throughout; device pass pending |
| 2.4.4 Link Purpose (In Context) | Supports | Citation links read "Source: <host>" |
| 2.5.1 Pointer Gestures | Supports | Tap-only interactions; no path-based gestures required |
| 2.5.2 Pointer Cancellation | Supports | Standard up-event activation (InkWell/buttons) |
| 2.5.3 Label in Name | Partially Supports | Visible text is the accessible name via merged nodes; device pass pending |
| 2.5.4 Motion Actuation | Not Applicable | No motion-based input |
| 3.1.1 Language of Page | Supports | App locale en; system-declared |
| 3.2.1 On Focus | Supports | No focus-triggered context changes in source |
| 3.2.2 On Input | Supports | Selecting an option never auto-advances; NEXT is explicit |
| 3.3.1 Error Identification | Supports | Sign-in, join-code, and share errors are textual, not color-only |
| 3.3.2 Labels or Instructions | Supports | All text fields carry labels (Email, Code, Class code) |
| 4.1.1 Parsing | Not Applicable | Per WCAG 2.2 retirement note |
| 4.1.2 Name, Role, Value | Partially Supports | Option tiles expose button role + selected state; legacy custom widgets pending device pass |

## Table 2: Success criteria, Level AA

| Criterion | Conformance | Remarks |
|---|---|---|
| 1.3.4 Orientation | Partially Supports | iPhone portrait primary; verify no hard lock on device |
| 1.3.5 Identify Input Purpose | Supports | Email fields use email keyboard + autocomplete hints |
| 1.4.3 Contrast (Minimum) | Partially Supports | Full palette measured + fixed 2026-07-04 (table above); legacy ochre-text usages remain |
| 1.4.4 Resize Text | Partially Supports | Scrollable layouts throughout; Dynamic Type XXL pass pending on device |
| 1.4.5 Images of Text | Supports | Wordmark and share-card PNGs only (share cards are exports, not UI) |
| 1.4.10 Reflow | Partially Supports | ListView-based; device pass pending |
| 1.4.11 Non-text Contrast | Partially Supports | Selected borders use primary (passes); hairline rules decorative; device re-check pending |
| 1.4.12 Text Spacing | Partially Supports | No fixed-height text containers in new screens |
| 1.4.13 Content on Hover or Focus | Not Applicable | No hover surfaces |
| 2.4.5 Multiple Ways | Not Applicable | Native app |
| 2.4.6 Headings and Labels | Supports | Section labels on every screen (READINESS BY DOMAIN, MOCK EXAM, ...) |
| 2.4.7 Focus Visible | Partially Supports | Material focus/ink states; device pass pending |
| 3.1.2 Language of Parts | Supports | Single-language content |
| 3.2.3 Consistent Navigation | Supports | Shell tabs + AppBar back pattern everywhere |
| 3.2.4 Consistent Identification | Supports | Shared tile/button/section idioms across features |
| 3.3.3 Error Suggestion | Supports | "Check with your professor and try again", "Check the address" |
| 3.3.4 Error Prevention | Supports | Purchases via Apple's flow; leaving a mock requires confirmation |
| 4.1.3 Status Messages | Partially Supports | Practice verdicts announced via SemanticsService; loading/refresh states pending device pass |

## Remaining work items (tracked)

1. On-device VoiceOver walkthrough of every screen; upgrade "pending
   device pass" rows to definitive levels.
2. Dynamic Type at accessibility sizes; fix any truncation found.
3. Reduce Motion audit of flutter_animate/confetti usages.
4. Re-check selected-state and border contrast (1.4.11) on device.
5. Custom semantics tree for the memory orbital field (the canvas now has
   a descriptive label and the list alternative; per-orb nodes are the
   full treatment).

Completed 2026-07-05: legacy ochre-as-text sweep (archetype colors, DID
YOU KNOW label, tour icons now use brandOchreText; HARD grade and GUESS
confidence buttons use ink-on-ochre instead of white at 2.4:1); portrait
labels confirmed already present on CardAvatar; memory field carries a
descriptive label pointing to the accessible list.
