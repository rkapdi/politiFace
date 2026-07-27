# Politiface Design System and UI Handover

**Version 1.0 · July 2026**
**Audience: Claude Code (implementation agent)**
**Author: Rissalat Kapdi**

---

## 0. How to use this document

This is a specification, not a suggestion list. Sections 1 through 6 are binding rules. Section 7 specifies components. Section 8 covers platform gotchas that will cost you hours if ignored. Section 9 is the accessibility floor. Section 10 covers the data architecture that the roster UI depends on.

If a requirement here conflicts with a component you found on Uiverse, Dribbble, or any other library, this document wins.

**Do not use em-dashes anywhere in code comments, copy, or documentation.** Use commas, periods, semicolons, colons, or parentheses.

---

## 1. Product context

Politiface is a civics education app built on gamified spaced repetition. Users identify US political figures and their roles, and the system schedules reviews based on recall performance.

Two audiences, two surfaces:

| Surface | Audience | Mode | Device |
| --- | --- | --- | --- |
| Student app | 18 to 24 year olds, community college | Dark | Mobile, evening use |
| Instructor dashboard | Faculty, e.g. Prof. Purcell at MDC | Light | Desktop, daytime, printable |

These are deliberately different modes. Do not force one mode across both.

The app is also a growth engine. Result cards get screenshotted and posted to TikTok and Instagram (@playpolitiface). Every visual decision must survive social recompression: hard edges and flat fills, never glow, blur, or gradients.

---

## 2. Design principles

**2.1 Colour is scarce.** Roughly 90 percent of any screen is neutral, 7 percent is brand yellow, 3 percent is semantic. If everything is coloured, nothing signals. Saturation is reserved for reward.

**2.2 Semantic colours mean one thing, always.** Mint means correct. Never use mint on a nav item, a settings icon, or a decorative element. The moment a reward colour appears decoratively, it stops functioning as a reward.

**2.3 No partisan colour in UI.** Red and blue are not neutral in a US political product. They do not appear as UI accents, state colours, card borders, or backgrounds. Party affiliation is data and belongs in a text label, never in a tint. This rule has no exceptions.

**2.4 Positive feedback is louder than negative.** Correct states fill, animate, and occupy more space. Missed states are quieter, smaller, and framed as incomplete rather than failed. Copy says "not yet," never "wrong."

**2.5 Flat only.** No gradients, no blur, no drop shadows with blur radius, no glow, no neumorphism. The only shadows in this system are hard offset shadows with zero blur.

**2.6 Reserve the spectacle.** Ticket cards, tilt effects, and corner ribbons are for milestones, personal bests, and share moments. Daily sessions get a quieter treatment. A reward that fires every time stops being a reward by day four.

---

## 3. Colour tokens

### 3.1 Core palette

```css
:root {
  /* Neutrals: dark surface (student app) */
  --ink:        #0B0B0F;  /* page canvas */
  --slate:      #17171C;  /* card surface */
  --slate-2:    #26262E;  /* raised / status segment */
  --line:       #2A2A33;  /* border on dark */
  --line-dim:   #3F3F4A;  /* thin separator, empty meter block */
  --muted:      #4A4A55;  /* inactive control border */
  --text-dim:   #5F5F6B;  /* inactive segment text */
  --text-3:     #6E6E7A;  /* metadata, captions */
  --text-2:     #A3A3AD;  /* secondary text */
  --paper:      #F5F5F4;  /* primary text on dark, card surface on light */

  /* Neutrals: light surface (instructor dashboard) */
  --canvas-lt:  #EDEDE8;  /* dashboard page canvas */
  --card-lt:    #FFFFFF;  /* card surface */
  --rule:       #000000;  /* brutalist border and offset shadow */

  /* Brand */
  --signal:     #FFD400;  /* THE brand colour */
  --signal-dk:  #B89800;  /* pressed-state shadow under yellow elements */

  /* Semantic */
  --correct:    #3DD68C;  /* mint: correct, mastered, ready */
  --notyet:     #FF9D00;  /* orange: missed, needs review */
  --tier:       #8B7CF6;  /* violet: locked in, unseen, terminal state */
}
```

### 3.2 Role assignments

| Token | Used for | Never used for |
| --- | --- | --- |
| `--signal` | Streak, primary CTA, brand mark, progress fill, corner ribbon, "needs help" flag | Correct answers, decorative accents |
| `--correct` | Correct answer state, mastered topic, "ready" stage | Anything in nav, settings, or chrome |
| `--notyet` | Missed answer, "not yet" stage, overdue review | Errors, destructive actions |
| `--tier` | "Locked in" terminal state, unseen cards | General accents |
| `--paper` | Body text on dark, card surface on light | Reward signalling |

### 3.3 Hard rules

- One yellow element per screen carrying the primary action. Never two.
- Correct and missed states must **never** be distinguished by colour alone. Always pair with an icon, a shape difference (solid versus hollow), and position. Roughly 8 percent of men have red-green colour deficiency and mint versus orange is exactly the pair they cannot resolve.
- On the light instructor surface, `--correct` sits at about 1.9:1 and `--notyet` at about 2.0:1 against white. Both are unusable there. On light surfaces, encode state as **solid black versus hollow black outline**. Yellow is the only chromatic colour permitted on the light surface.

### 3.4 Contrast reference (against `--ink`)

| Colour | Ratio | Verdict |
| --- | --- | --- |
| `--signal` #FFD400 | 13.2:1 | Pass AAA |
| `--correct` #3DD68C | 9.0:1 | Pass AAA |
| `--notyet` #FF9D00 | 9.1:1 | Pass AAA |
| `--tier` #8B7CF6 | 5.1:1 | Pass AA, do not use below 16px |
| `--paper` #F5F5F4 | 17.8:1 | Pass AAA |

---

## 4. Typography

Neo-brutalism depends on a heavy grotesque. Do **not** ship with a system font fallback.

```css
--font-display: 'Archivo', 'Archivo Black', system-ui, sans-serif;
--font-body:    'Inter', system-ui, sans-serif;
--font-mono:    'JetBrains Mono', ui-monospace, 'SF Mono', monospace;
```

Load via Fontsource or self-host. Do not use Proxima Nova (licensed, and the Uiverse source that references it silently falls back to system sans).

| Role | Size | Weight | Notes |
| --- | --- | --- | --- |
| Score numeral | 46 to 52px | 500 | Tabular figures. `font-variant-numeric: tabular-nums` |
| Card title | 20 to 22px | 500 | |
| Body | 15 to 16px | 400 | line-height 1.4 |
| Metadata / caption | 12 to 13px | 400 | `--text-3` |
| Status bar segment | 12 to 13px | 400 | mono, letter-spacing 0.06em |
| Micro label | 11px | 500 | letter-spacing 0.1em |

Weights: 400 and 500 only. Do not use 600 or 700; the display face carries the weight.

**Do not go below 11px anywhere.** The powerline status bar is set at 11px in the reference mock; ship it at 13px in the student app.

---

## 5. Geometry and the brutalist treatment

```css
--border-card:   4px;   /* card borders (6px on hero cards) */
--border-ctrl:   3px;   /* toggles, tabs, inline controls */
--offset:        6px;   /* hard shadow offset, cards */
--offset-ctrl:   4px;   /* hard shadow offset, controls */
--radius:        0;     /* default */
--radius-soft:   5px;   /* toggle track, small chips only */
```

**Offset shadow rule.** Hard shadows have zero blur: `box-shadow: 6px 6px 0 <colour>`.

The shadow colour depends on the surface:

- On the **light** instructor surface: `box-shadow: 6px 6px 0 #000`
- On the **dark** student surface: a black shadow is invisible. Use `box-shadow: 12px 12px 0 var(--signal)`.

This substitution is required, not optional. The offset shadow is the signature of the style and it must remain visible.

**Density rule.** Offset shadows work at component scale and become noise when repeated in a dense list. In a settings list or a table, apply the shadow to the interactive knob or the selected row only, and keep the rest to a flat border.

---

## 6. Motion system

### 6.1 Global

```css
--dur-fast:  120ms;
--dur-base:  200ms;
--dur-slow:  380ms;
--ease:      cubic-bezier(0.2, 0, 0, 1);
```

**Every animation in this system must be gated:**

```css
@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; transition: none !important; }
}
```

On native iOS, check `UIAccessibility.isReduceMotionEnabled`. On React Native, `AccessibilityInfo.isReduceMotionEnabled()`.

This is not a nicety. The results card fires after every session, so a motion-sensitive user encounters it dozens of times a week.

### 6.2 Press feedback (brutalist)

Every interactive element with an offset shadow collapses on press:

```css
.brutal:active {
  transform: translate(3px, 3px);
  box-shadow: none;
}
```

Do not use `:hover` for anything functional. This is a mobile app. Every hover-dependent interaction in the source components we referenced is dead on touch. Use `pointerdown` / `pointerup`, or Motion's `whileTap`.

### 6.3 Results card entrance sequence

Orchestrate as one moment, not scattered effects. Total duration about 900ms.

| t | Element | Animation |
| --- | --- | --- |
| 0ms | Card | Scale 0.94 to 1.0, opacity 0 to 1, `--dur-slow` |
| 180ms | Score numeral | Count up from 0 to final value over 500ms, ease-out |
| 220ms | Barcode bars | Stagger in left to right, 40ms apart, scaleY 0 to 1 from bottom |
| 620ms | Corner ribbon | Slide in along its 45 degree axis, `--dur-base` |
| 640ms | Haptic | `notificationAsync(Success)` on a personal best, `impactAsync(Light)` otherwise |

The ribbon lands last and with the haptic. That is the reward beat. Do not move it earlier.

The ribbon must animate on **mount**, not on hover. The original source component gated its ribbon text swap behind `:hover`, which means its most interesting behaviour never fires on a phone.

### 6.4 Gyroscope tilt

Applies to milestone result cards and share previews only. Not the daily card.

Implementation:

- Read `DeviceOrientationEvent` `beta` (front-back) and `gamma` (left-right).
- **Clamp the tilt to plus or minus 10 degrees.** Past about 12 it stops reading as physical and starts reading as a toy.
- **Capture the first reading as the neutral baseline.** People hold phones at roughly 50 to 70 degrees from flat. Mapping raw `beta` to `rotateX` pins the card at maximum tilt the instant it appears.
- **Smooth with a lerp:** `current += (target - current) * 0.12`. Raw sensor data is jittery and the card will visibly tremble without it.
- Animate `transform` only. Never animate layout properties.
- Tear down the listener on unmount. A `deviceorientation` listener left running drains battery.

Layered parallax is what sells it. Three depths:

| Layer | Movement |
| --- | --- |
| Card body | `rotateX` / `rotateY`, up to 10 degrees |
| Offset shadow | Moves **opposite** the tilt: `box-shadow: ${12 - x*14}px ${12 - y*14}px 0 var(--signal)` |
| Ribbon and score | Drift with the tilt at about 7px and 5px respectively |

The shadow moving opposite the tilt is the detail that makes the card read as a physical object rather than a rotated image. Do not omit it.

```js
async function enableTilt() {
  if (typeof DeviceOrientationEvent?.requestPermission === 'function') {
    const state = await DeviceOrientationEvent.requestPermission();
    if (state !== 'granted') return false;
  }
  let base = null;
  window.addEventListener('deviceorientation', (e) => {
    if (base === null) base = { beta: e.beta, gamma: e.gamma };
    targetX = clamp((e.gamma - base.gamma) / 25, -1, 1);
    targetY = clamp((e.beta  - base.beta ) / 25, -1, 1);
  });
  return true;
}
```

`requestPermission()` must be called from inside a user gesture handler and requires HTTPS. Call it from the tap that reveals the results card so the prompt lands at a moment that makes sense. Handle denial silently with a static card.

If the app is native SwiftUI or UIKit, do **not** reach for CoreMotion first. `UIInterpolatingMotionEffect` in a `UIMotionEffectGroup` gives you this in about eight lines, respects Reduce Motion automatically, and needs no permission prompt.

If React Native, use `expo-sensors` DeviceMotion driven through `react-native-reanimated` shared values so it runs on the UI thread. Routing sensor updates through setState will jank at 60Hz.

### 6.5 Haptics

`navigator.vibrate` does nothing on iOS Safari. Use the Capacitor Haptics plugin in a WebView or `expo-haptics` in React Native.

| Event | Haptic |
| --- | --- |
| Correct answer | `impactAsync(Light)` |
| Missed answer | none (do not punish physically) |
| Toggle change | `selectionAsync()` |
| Results card lands | `impactAsync(Light)` |
| Personal best or milestone | `notificationAsync(Success)` |

---

## 7. Component specifications

### 7.1 Results card (student, dark surface)

The end-of-session card has three jobs in strict priority order: **deliver the reward, hook the return, enable the share.** Most quiz apps do the first, forget the second, and bolt on the third.

Structure (poster variant, used for milestones and personal bests):

```
+------------------------------------------+
|  SESSION 47                    [RIBBON]  |  <- micro label + corner ribbon
|  ________                                |
|                                          |
|  [8] / 10                                |  <- yellow highlight behind numeral
|  Your best run this week                 |
|                                          |
|  ▮▮▯▮▮▮▯▮▮▮                              |  <- data barcode, 10 bars
|  Q1                              Q10     |
|  ========================================|
|  🔥 12 days              NEXT IN 14H     |  <- return hook
|  [           SHARE           ]           |
+------------------------------------------+
```

Specs:
- Surface: `--paper` card on `--ink` canvas, `6px solid #000` border, `12px 12px 0 var(--signal)` shadow, `rotate(-2deg)`
- Max width 320px, `width: 100%`. Never a fixed width; a fixed 320px plus borders plus offset plus rotation overflows a 320px viewport.
- Score numeral gets a `--signal` block behind it (`padding: 0 6px`)
- Serial number in the micro label. "Session 47" makes the card an artifact rather than a screen, and gives people something to reference when they post it.

**Rotation caution:** rotated text renders slightly soft on some Android devices. If the score numeral looks fuzzy on a mid-range test device, rotate the card container and counter-rotate the numeral back to zero.

Daily (non-milestone) variant: same content, no rotation, no tilt, no ribbon unless a state fired, smaller shadow.

### 7.2 Corner ribbon

45 degree band across the top-right corner. `--signal` fill, `3px solid #000` top and bottom borders, black text, 11 to 13px, `letter-spacing: 0.14em`.

**The ribbon is state-driven, not decorative.** It renders only when something notable happened, and its text is the state:

`PERFECT` · `NEW BEST` · `STREAK SAVED` · `10 IN A ROW` · `CLOSE ONE` · `NEEDS HELP` (instructor surface)

If no state qualifies, the ribbon does not render. A ribbon that always appears is wallpaper.

Parent needs `position: relative; overflow: hidden`.

### 7.3 Data barcode

The signature motif of the system. It appears on three surfaces with the same visual grammar and different data:

| Surface | Bars | Meaning |
| --- | --- | --- |
| Results card | 10 | One per question this session |
| Roster card (instructor) | 8 | One per course topic |
| Powerline status bar | 8 | Projected score meter |

Rendering:

- **Dark surface:** solid `--correct` for hit, `--notyet` at 58 percent height for miss
- **Light surface:** solid `#000` for hit, white with `2px solid #000` outline for miss

Solid versus hollow is colourblind-proof, prints, and is more brutalist than a colour pair. Use it wherever the surface is light.

Bars are `flex: 1` with a 3 to 4px gap, 26 to 40px tall. Label the axis (`Q1` / `Q10`, or `7 of 8 topics`).

### 7.4 Powerline status bar

Replaces the previous boxed four-segment stage tracker. Stages: `not yet` → `on track` → `ready` → `locked in`.

**Do not use powerline glyph characters.** Those live in patched Nerd Fonts and cannot be relied on in a mobile app or browser. Build every chevron with `clip-path`.

```css
.pl  { display:flex; align-items:stretch; height:30px;
       font-family:var(--font-mono); font-size:13px; letter-spacing:.06em;
       overflow:hidden; border-radius:3px }
.sg  { display:flex; align-items:center; padding:0 11px; white-space:nowrap }
.ar  { width:13px; flex:none }
.ar > span { display:block; width:100%; height:100% }
.rt > span { clip-path: polygon(0 0, 0 100%, 100% 50%) }   /* points right */
.lt > span { clip-path: polygon(100% 0, 100% 100%, 0 50%) } /* points left */
```

**The chevron colour rule, which is easy to get backwards:** the arrow element's own `background` is the **next** segment's colour; the clipped child inside it is the **previous** segment's colour. Invert these and the chevrons render as notches.

Layout: left group uses right-pointing chevrons, a flexible `--slate` spacer, then the right group uses left-pointing chevrons.

Colour behaviour, following tmux window-list convention:

- Only the **active** segment is coloured. Inactive segments are `--slate` background with `--text-dim` text.
- Active segment colour by stage: `not yet` → `--notyet`, `on track` → `--signal`, `ready` → `--correct`, `locked in` → `--tier`. Text on active segments is `--ink`.
- Between two **inactive** segments, use a thin `›` character in `--line-dim`, not a solid chevron. A solid chevron between two identical backgrounds is invisible. This is the powerline convention for same-colour adjacency and it is the detail that makes it read as authentic.

Right group carries volatile state: score meter blocks, projected range, days remaining. Days remaining changes colour by urgency, ending on `--signal` inside 7 days.

### 7.5 Toggle switch (settings)

```css
.sw   { position:relative; width:52px; height:28px; flex:none }
.sw input { position:absolute; inset:0; opacity:0; width:100%; height:100%;
            margin:0; cursor:pointer; z-index:2 }
.trk  { position:absolute; inset:0; border:3px solid var(--muted);
        border-radius:6px; background:var(--slate); transition:.2s }
.knb  { position:absolute; top:3px; left:3px; width:22px; height:22px;
        border-radius:4px; background:var(--text-2);
        box-shadow:0 3px 0 var(--ink); transition:.2s }
.sw input:checked ~ .trk { background:var(--signal); border-color:var(--signal) }
.sw input:checked ~ .knb { transform:translateX(24px); background:var(--ink);
                           box-shadow:0 3px 0 var(--signal-dk) }
.sw input:active ~ .knb  { box-shadow:none; transform:translateY(3px) }
.sw input:checked:active ~ .knb { box-shadow:none;
                           transform:translateX(24px) translateY(3px) }
.sw input:focus-visible ~ .trk { outline:3px solid var(--signal); outline-offset:3px }
```

Requirements:

- **Wrap the entire settings row in the `<label>`.** The switch at 52 by 28 is under Apple's 44 by 44 minimum on its own; making the full row the tap target fixes it and matches iOS convention.
- Keep the real `<input>` at full size with `opacity: 0` layered on top. Do **not** use `width: 0; height: 0`, which kills the focus ring entirely.
- Add `role="switch"`. VoiceOver then announces "on" and "off" rather than "checked" and "unchecked."
- Every switch needs an accessible name. Wrapping the row provides it for free.
- Checked knob is `--ink` (black), not white. On a yellow track, black gives far more separation.
- The offset shadow goes on the **knob only**, never the track. Ten track shadows down a settings list is noise.
- If native, add a drag gesture. Tap-only toggles feel subtly broken to people who drag.

### 7.6 Auth card

**Do not gate the app behind this.** Let users complete a full session with no account, then surface signup immediately after the results card, framed as "save your streak." Conversion at that moment is far higher than at cold open, and App Store guideline 5.1.1(v) restricts requiring registration for content that works without it.

Order of methods, top to bottom:

1. Continue with Apple (required by guideline 4.8 if any third-party sign-in is offered)
2. Continue with Google
3. Divider
4. Email address plus continue

Email and password is the highest-friction path and must not be the default.

Structure: tabs (log in / sign up) above the card, **not** a toggle switch. A switch means on/off, not navigation. The source component's toggle was also 50 by 20, well under minimum target size.

Do **not** implement the 3D flip between login and signup. Reasons, all real:
- `backface-visibility` plus `preserve-3d` is flaky in Safari; the back face bleeds through mid-rotation
- The hidden face stays in the tab order and is readable by VoiceOver, producing two email fields and two password fields with no way to tell which is live. If you keep any flip anywhere, mark the inactive face `inert`.
- Two password fields in two forms on one screen confuses iCloud Keychain and 1Password, and the 3D transform mispositions the autofill dropdown

The flip effect is worth keeping for a **face card revealing an answer**, where autofill and VoiceOver will not fight it.

Include a visible skip: "Keep playing without an account."

Yellow appears on exactly one element: the final continue action.

### 7.7 Roster card (instructor, light surface)

Replaces social links with the data an instructor actually needs.

```
+---------------------------+
| [MR]              [FLAG]  |  <- initials avatar, optional ribbon
| Maya Rodriguez            |
| POS 2041 · Sec 04         |
| ▮▮▮▮▮▯▮▮                  |  <- topic barcode, 8 bars
| 7 of 8 topics             |
| ==========================|
| 18 day streak      Today  |
+---------------------------+
```

- Grid: `repeat(auto-fit, minmax(180px, 1fr))`, gap 20px. Never fixed dimensions; the roster must reflow from a laptop sidebar to a wide monitor, and fixed height breaks on long names.
- `4px solid #000` border, `6px 6px 0 #000` shadow, white card on `--canvas-lt`
- Avatar is **initials, not photos.** No upload pipeline, no moderation surface, no storage cost, no directory-photo question. If personalisation is wanted later, offer a fixed set of civic-themed marks to choose from.
- Corner ribbon reads `NEEDS HELP`. On a roster of thirty, the instructor's real question is "who do I email," and the ribbon answers it at a glance.
- If any hover reveal is added, animate `opacity` and `transform`, never `height`. Animating height forces layout every frame and will stutter across thirty cards.

**The name row needs a `min-height` and the avatar must never disappear.** See section 10: the same component renders under three privacy tiers and the layout must not shift between them. If it reflows when privacy turns on, someone will decide not to turn it on.

### 7.8 Roster reconciliation panel

The view nobody plans for and the one that determines whether an instructor trusts the tool.

Reality: thirty enrolled, twenty-four join cleanly, two use personal Gmail, one typos the domain, three never show up.

Required elements:

- Section join code, displayed large in mono with wide letter-spacing, plus a **rotate code** action (codes leak between semesters)
- Three counts: matched / needs matching / not joined
- A list of accounts that joined with a non-school address, each with a **match to roster** action
- A list of enrolled students who have not joined, with a **send reminder** action

Behaviour:

- **Never hard-reject an unrecognised email domain.** A student who typos `mymdc.ne` gets stuck at signup with no path forward and emails the professor instead of you. Accept into an unmatched bucket and let the instructor resolve it.
- The join code is a shared secret, not identity. It grants **student role only**, never instructor. Scope it to the section, not the course, so multiple sections stay separate.
- Verified email on an allowed domain is what makes the roster trustworthy. Magic link or OTP, then attach to the section.
- **Handle Apple Hide My Email.** `@privaterelay.appleid.com` passes verification and fails every domain rule. Detect the domain and prompt for a school email as a second step, or the student lands silently in the unmatched bucket.
- Ask for a display name at signup. College email local parts are opaque (`mrodrig042@`) and an instructor cannot map thirty of those to faces.
- Support both entry paths: join code (the classroom demo moment, thirty phones at once) and roster import by email (accuracy, and it pre-populates names).

---

## 8. Platform notes

| Issue | Detail |
| --- | --- |
| `:hover` | Non-functional on touch. Every hover-gated behaviour must be re-homed to mount, tap, or focus. |
| `DeviceOrientationEvent` | iOS 13+ requires `requestPermission()` from a user gesture, over HTTPS. Users can also disable it under Settings, Safari, Motion and Orientation Access. Handle denial gracefully. |
| Powerline glyphs | Require Nerd Fonts. Use `clip-path` polygons instead. |
| Nested form controls | A `<label>` may contain at most one labelable control. The source auth component wraps a checkbox and two `<form>` elements in one label, which makes the entire form contents the accessible name of that checkbox. Do not replicate. |
| `backface-visibility` | Flaky in Safari with `preserve-3d`. Add `translateZ(0)` and test on a real device, not the simulator. |
| Autofill | Two password fields on one screen confuses iCloud Keychain and 1Password. |
| Screenshot export | Ticket and poster shapes relying on absolutely positioned notch circles or CSS masks commonly break in `html-to-image` and `dom-to-image`. Test an export at 1080 by 1350 before committing to the shape. |
| Fixed widths | Every source component we referenced uses a fixed px width. All must become `max-width` plus `width: 100%`. |

---

## 9. Accessibility floor

Target: **WCAG 2.1 AA.** This is a procurement requirement for institutional sales, not an aspiration. It appears on HECVAT and in VPAT reviews.

- All text meets 4.5:1, large text 3:1. See the contrast table in 3.4.
- **No hover-only content.** Content revealed only on hover with no keyboard path fails 2.1.1 and 1.4.13. This is a concrete VPAT finding.
- All interactive targets at least 44 by 44 points.
- Visible `:focus-visible` ring on every control, `3px solid var(--signal)` with `outline-offset: 3px`.
- `prefers-reduced-motion` respected globally.
- State never encoded by colour alone. Icon plus shape plus position.
- `role="switch"` on toggles, `aria-label` or wrapping label on every control.
- Hidden faces of any flipped or transformed element marked `inert`.
- Support Dynamic Type / text scaling. Do not lock font sizes in px on native.

---

## 10. Data and privacy architecture

Current deployment (Prof. Purcell, MDC) runs fully open. The architecture below costs almost nothing now and unlocks the second and third institution later.

**Governing principle: display is reversible, collection is not.** Be liberal about what you display and conservative about what you store and transmit. A name shown today can be hidden tomorrow with a config change. A name collected today lives in your database, your backups, your logs, and any third-party vendor you piped events to.

### 10.1 Roster visibility tiers

One enum on the organisation record, default `open`. The **same component** renders every tier.

| Tier | Instructor sees | Enable when |
| --- | --- | --- |
| `open` | Full name, optional photo, individual drill-down | Purcell, MDC today |
| `directory` | Full name, initials only, no photo | Institution restricts photo storage |
| `pseudonymous` | "Student 14", individual progress | FERPA directory opt-out, stricter district |
| `aggregate` | No individual rows, cohort distribution, cells under n=5 suppressed | Research use, K-12, minors |

**Enforce at the API serializer, not in the component.** One `resolveIdentity(student, policy)` function server-side. If the endpoint returns real names and the UI merely hides them, anyone can open devtools and you have a disclosure incident with a compliance story that reads as deliberate. The client must never receive what it is not allowed to display.

### 10.2 Build now, cost nothing, painful to retrofit

- `org_id` on **every** row from the first migration. Retrofitting tenant isolation is the single most expensive refactor in B2B SaaS.
- `roster_visibility` enum on the org, default `open`.
- `directory_opt_out` boolean on the student record. Unused now. It is a column.
- **Hashed identifiers for anything leaving your system.** Analytics, crash reporting, and especially any LLM API call. This is the genuinely irreversible one: a student name that reached a third-party vendor's logs cannot be recalled.
- `instructor_views` audit table: timestamp, instructor, student, action. Cheap to write, impossible to backfill, directly answers several HECVAT items.
- `data_residency` and `retention_days` fields on the org. Unused now. Canadian institutions will ask.

### 10.3 Do not collect

Student ID numbers. They are generally not directory information the way name and email are, which raises the sensitivity of the whole record, and they give you nothing that verified email does not already provide for roster matching.

---

## 11. Anti-patterns

Sourced from the component libraries this system draws on. Every one of these was present in at least one referenced component.

1. Hover-gated behaviour in a mobile app
2. Fixed pixel widths and heights on cards
3. Animating `height` or other layout properties
4. `width: 0; height: 0` on a visually hidden input (kills focus)
5. Blue as a UI accent (partisan in this product)
6. Neon glow, gradients, blur (fails social recompression, softens small text)
7. Decorative elements occupying the highest-value real estate on a card
8. Semantic colours reused decoratively
9. Rewards that fire every time
10. Touch targets under 44 by 44
11. Colour-only state encoding
12. Client-side-only privacy enforcement

**Standing rule for external component libraries:** Uiverse, CodePen, and similar are sources of *aesthetic ideas and CSS techniques*, never sources of components. Every referenced component was built to look good in a 400px showcase tile and carries the same three defects: no responsive behaviour, hover-dependent interaction, and accessibility gaps.

---

## 12. Build order

1. Token layer (sections 3, 4, 5) as CSS custom properties or a Tailwind config
2. Primitives: button, toggle, tabs, input, corner ribbon, data barcode
3. Results card, static variant, with entrance sequence
4. Powerline status bar
5. Auth card and post-session signup prompt
6. Instructor roster card and grid with the three visibility tiers wired to a config flag
7. Reconciliation panel
8. Gyroscope tilt, milestone variant only, behind a settings toggle

Ship 1 through 7 before 8. The tilt is the most fun and the least load-bearing.

---

## 13. Open questions

- Exact MDC student email domain needs confirming before the allowlist is written.
- Definition of "needs help" on the roster card. Days since last session, topics below mastery, streak broken, or a composite. **This threshold is the entire instructor product.** Ask Purcell directly rather than guessing.
- Whether Purcell prefers reading out a join code or pasting a roster. Determines which entry path gets built well.
- Whether the powerline treatment lands with students. It reads as developer culture and the student audience may not parse it. Test with a few of Purcell's students before shipping it student-facing. Fallback: keep it on the instructor dashboard, where the density is an asset.
