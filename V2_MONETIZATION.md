# Politiface V2 — Monetization Model (decision doc)

*Draft, 2026-06-25. Grounded in a deep-research pass (RevenueCat State-of-Subscription-Apps 2024/25/26, Apple App Store Review Guidelines, Epic v. Apple 9th Cir. ruling, Duolingo primary). Numbers marked "(rec)" are our recommendation, not a cited benchmark.*

## Mission anchor
Politiface = a game to promote **political literacy worldwide**. US-first; Florida FCLE is the launch **beachhead**, not the product. Monetization must serve the *general* learner, not just exam-takers. Core civic learning stays free forever — we monetize **depth, volume, study-tools, and exam-prep apparatus**, never the basic ability to learn.

## What the research validated
- **Hybrid is mainstream, not novel.** ~90% of subscription-app users never convert; hybrid buyers are only ~7% of buyers but drive **~25% of revenue**; 35% of subscription apps now blend subscriptions with consumables/lifetime purchases. *(RevenueCat)*
- **Duolingo already retreated from "Hearts" to "Energy"** to soften backlash. Super ($6.99/mo) = unlimited energy + no ads + personalized review; Max ($14/mo) = +AI. *(Duolingo primary)* Lesson: even the category leader treats a punitive lives system as a liability to manage.
- **Education pricing:** median **$9.99/mo, $44.99/yr** (highest annual median of any category), $4.99/wk. Annual plans dominate (59–66% adoption). Trials skew long (80%+ at 5–9+ days). *(RevenueCat 2026 Education)*
- **Freemium converts ~5× worse than a hard paywall** (D35 download-to-paid ~2.2% freemium vs ~12% hard paywall). A free game trades conversion rate for reach — so **the Pass attach-rate and trial/paywall design carry disproportionate weight**.

## The model

### One entitlement layer (payment-agnostic)
Capability flags on the user record — e.g. `unlimited_energy`, `fcle_prep`, `plus`. Granted by *any* source (consumable / non-consumable / subscription / promo code) with an expiry. **The app checks capability only, never how it was granted.** Use **RevenueCat** over hand-rolled StoreKit — it manages the IAP↔entitlement mapping, restore, and cross-device sync (which Apple requires for subscriptions anyway).

### Tier 1 — FREE forever (the engine)
The full core civics game for your region (US federal): faces, daily trivia, **structured daily learning + FSRS reviews**, streaks, school leaderboards. Plus **one free full FCLE Mock** as the exam-prep taste. This is the acquisition / virality / retention layer — it's the v1 you already shipped.

### The energy mechanic (handle with care — see Risk #1)
**Gate volume/grind, never core learning.** Energy applies only to high-volume *grind* modes (Endless), **not** to the daily structured lesson + reviews. So a free user can always do their real civic learning every day; energy only bites when someone is power-grinding the game loop.
- (rec) Cap **5**, regen **+1 per 30 min** (full ~2.5 h); a wrong answer in Endless costs 1; daily lessons/reviews exempt.
- Refill paths: Plus (unlimited), optional rewarded ad (+1), or gems. Purchased energy/gems **must not expire** (Apple 3.1.1).

### Tier 2 — Politiface Plus (auto-renewable subscription)
**(rec) $9.99/mo · $44.99/yr · 7-day free trial.** All-access for the committed general learner:
unlimited energy + no ads, all depth content, **all exam packs included** (FCLE + future), advanced study tools (retention analytics, weak-area, unlimited mocks), and future-country content as it ships. The "continually updated content" is what makes it Apple-compliant as a subscription (3.1.2a) and what justifies *recurring* payment.

### Tier 3 — Exam Passes (non-consumable, one-time)
**FCLE Pass (rec) $29.99 one-time** — deliberately **below the Plus annual ($44.99)** so intent self-segments: *"just need to pass once → buy the Pass, cheaper than a year of Plus; want everything ongoing → Plus is better value."* Unlocks full FCLE prep (unlimited mocks, all 4 domains, readiness, weak-area, explanations+sources). **Plus includes every Pass**, so a subscriber is never double-charged. USCIS citizenship is the obvious second Pass; the same packaging generalizes to other exams/countries.

## Apple compliance checklist (what gets you rejected)
- All three tiers **must** use IAP — energy = **consumable**, Pass = **non-consumable**, Plus = **auto-renewable subscription**. No license keys / QR / private unlock mechanisms (3.1.1).
- Purchased currency/energy **may not expire**; provide a **Restore Purchases** path for the Pass.
- Subscription must last ≥7 days, deliver **ongoing/updated value**, and **sync across devices**; include a manage-subscription link.
- **Account & data deletion** flow required (already Epic 0.4).
- Register for the **Small Business Program** → 15% commission (under $1M/yr) instead of 30%.
- **Do NOT rely on the US external-purchase-link carve-out at launch.** It exists post Epic v. Apple (9th Cir. affirmed the anti-steering injunction Dec 11 2025) but is actively litigated/possibly paused into 2026. Ship standard IAP; treat web-pay as a later margin optimization, not a launch dependency.

## Top risks
1. **Energy on an education app = mission risk.** Paywalling civic *learning* would betray the mission and invite Duolingo-style backlash (which pushed even Duolingo to rebrand Hearts→Energy). Mitigation: energy gates grind/volume only; daily learning is always free.
2. **Pass↔Plus cannibalization.** Mitigation: Pass priced below Plus annual; segment on intent (one goal vs all-access); Plus bundles all Passes.
3. **Freemium's low conversion (~2%).** A free game wins on reach, not conversion rate — so the free-mock→Pass funnel and the Plus trial must be strong, and Pass attach matters as much as subscriptions.

## Highest-leverage decisions still open
1. **Energy: in or out for v2 launch?** Real fork — ship the (carefully-scoped) energy mechanic now, or launch with depth/tools/Passes monetization only and add energy later once retention data exists. Energy is the riskiest piece for an education brand.
2. **Exact price points** — confirm Plus $9.99/$44.99 and FCLE Pass $29.99 (need comparable exam-prep app pricing — UWorld/Magoosh — to anchor the Pass; research didn't surface exact figures).
3. **Free FCLE taste** — one full mock vs. one mock + one domain. Bigger taste = more goodwill + funnel, but risks giving away enough that motivated students don't convert.

## Caveats on the evidence
Nearly all quantitative benchmarks come from RevenueCat (the de-facto industry source — 115k+ apps — but a vendor with a pro-subscription interest, and figures are cross-category, not civic-game-specific). Pricing shifted between the 2024 ($59.99 annual) and 2026 ($44.99) reports — cite latest. The Apple external-link situation is time-sensitive. Civic/trivia-game-specific conversion + Duolingo's actual disclosed conversion rate were *not* found and remain open.
