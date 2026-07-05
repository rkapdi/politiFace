# Accessibility Conformance Report scaffold (VPAT 2.5, WCAG edition)

Procurement deliverable for public institutions (DOJ 2024 ADA Title II
rule; WCAG 2.1 AA is the target). This scaffold lists every WCAG 2.1 A/AA
criterion relevant to a native iOS app; fill the Conformance column from a
real audit pass before sharing externally. Levels: Supports, Partially
Supports, Does Not Support, Not Applicable.

**Product:** Politiface iOS app, version [x.y.z]
**Report date:** [date]
**Evaluation methods:** VoiceOver walkthrough of every screen, Dynamic Type
at largest accessibility sizes, contrast measurement of the editorial
palette in light and dark modes, Switch Control spot checks, automated
Flutter semantics checks in widget tests.

## Table 1: Success criteria, Level A

| Criterion | Conformance | Remarks |
|---|---|---|
| 1.1.1 Non-text Content | [ ] | Politician portraits and marks need semantic labels |
| 1.3.1 Info and Relationships | [ ] | Flutter Semantics tree per screen |
| 1.3.2 Meaningful Sequence | [ ] | |
| 1.3.3 Sensory Characteristics | [ ] | Correct/incorrect uses icon + color + text, not color alone |
| 1.4.1 Use of Color | [ ] | Readiness bars pair color with percentage text |
| 1.4.2 Audio Control | Not Applicable | No auto-playing audio |
| 2.1.1 Keyboard | [ ] | External keyboard / Switch Control |
| 2.1.2 No Keyboard Trap | [ ] | |
| 2.2.1 Timing Adjustable | [ ] | Mock has no time limit by design |
| 2.2.2 Pause, Stop, Hide | [ ] | Confetti/animation controls |
| 2.3.1 Three Flashes | Supports | No flashing content |
| 2.4.1 Bypass Blocks | Not Applicable | Native app navigation |
| 2.4.2 Page Titled | [ ] | Every screen has an AppBar title |
| 2.4.3 Focus Order | [ ] | |
| 2.4.4 Link Purpose (In Context) | [ ] | Citation links state their source |
| 2.5.1 Pointer Gestures | [ ] | No path-based gestures required |
| 2.5.2 Pointer Cancellation | [ ] | |
| 2.5.3 Label in Name | [ ] | |
| 2.5.4 Motion Actuation | Not Applicable | |
| 3.1.1 Language of Page | [ ] | |
| 3.2.1 On Focus | [ ] | |
| 3.2.2 On Input | [ ] | |
| 3.3.1 Error Identification | [ ] | OTP sign-in errors are textual |
| 3.3.2 Labels or Instructions | [ ] | |
| 4.1.1 Parsing | Not Applicable (per WCAG 2.2 note) | |
| 4.1.2 Name, Role, Value | [ ] | |

## Table 2: Success criteria, Level AA

| Criterion | Conformance | Remarks |
|---|---|---|
| 1.3.4 Orientation | [ ] | iPhone portrait primary; verify no lock where avoidable |
| 1.3.5 Identify Input Purpose | [ ] | Email field uses keyboardType email |
| 1.4.3 Contrast (Minimum) | [ ] | Editorial palette must be re-measured in both modes |
| 1.4.4 Resize Text | [ ] | Dynamic Type up to accessibility sizes without loss |
| 1.4.5 Images of Text | [ ] | Wordmark only |
| 1.4.10 Reflow | [ ] | |
| 1.4.11 Non-text Contrast | [ ] | Option tile borders, progress bars |
| 1.4.12 Text Spacing | [ ] | |
| 1.4.13 Content on Hover or Focus | Not Applicable | |
| 2.4.5 Multiple Ways | Not Applicable | Native app |
| 2.4.6 Headings and Labels | [ ] | |
| 2.4.7 Focus Visible | [ ] | |
| 3.1.2 Language of Parts | [ ] | |
| 3.2.3 Consistent Navigation | [ ] | |
| 3.2.4 Consistent Identification | [ ] | |
| 3.3.3 Error Suggestion | [ ] | |
| 3.3.4 Error Prevention (Legal, Financial, Data) | [ ] | Purchases go through Apple's own flow |
| 4.1.3 Status Messages | [ ] | Answer feedback announced to VoiceOver |

## Known work items (running list)

- Semantic labels for card avatars and the memory orbital field.
- Contrast audit of `EditorialPalette` light/dark variants (flagged in the
  execution plan; the ink/gold game-vision palette must be re-checked
  before any adoption).
- VoiceOver labels and hints for the mock exam option tiles.
- Announce practice-mode correctness with `SemanticsService.announce`.
