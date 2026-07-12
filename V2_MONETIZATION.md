# Politiface V2 — Monetization & Business Model (decision doc)

*Rev 2, 2026-06-26. Grounded in two deep-research passes (RevenueCat State-of-Subscription-Apps 2024/25, Apple Review Guidelines, Epic v. Apple 9th Cir., Duolingo, Top Hat, Ground News, Florida BOG civic-literacy guidance, F.S. 1007.25, Knight/Carnegie/iCivics). Numbers marked "(rec)" are our recommendation; cited numbers carry a source.*

## Mission anchor & the repositioning
Politiface = a game to promote **political literacy worldwide**. The v2 monetization thesis has moved **from "FCLE exam prep" to "civic empowerment / agency"** — *"learn how the machine of power actually works, realize that as a citizen you have power, take back control,"* aimed at a polarized, politically-anxious **mass** audience. **Nonpartisan trust is the brand, the moat, AND the business model** (see Ethics, below). FCLE + the faculty channel are the **wedge and the proof-of-efficacy** ("it literally helps students pass a state exam"), not the revenue engine.

## Demand reality — why we do NOT lead with exam-prep revenue
- Florida schools blanket students with **free** FCLE prep (free Canvas courses, library LibGuides at nearly every college, free practice tests). *(easternflorida.edu LibGuide)*
- The requirement is satisfiable by **a course** (POS 2041 / US History) **or** AP/CLEP — the standalone exam is a minority path. F.S. 1007.25 requires **both a course and an assessment**; it carries **no funding/appropriation** a vendor could tap. *(leg.state.fl.us 1007.25; flbog.edu 2025 guidance)*
- **The official FCLE is locked to state vendor Cambium Learning** — proctored, cannot be imported to an LMS. **Politiface can only ever be prep/practice, never the official exam.** *(flbog.edu 2025 guidance)*
- Adjacent USCIS citizenship prep: official app is **free**; paid apps monetize on ad-removal/small features (low-ARPU freemium).
→ Individual willingness-to-pay for exam prep is **low**. FCLE is strictly top-of-funnel.

## The honest math: pure B2C will NOT reach $1M alone
RevenueCat benchmarks: global download-to-paid is **1.7%** in 30 days (NA ceiling ~9.4% Health&Fitness / 9.8% Business); **only ~17%** of subscription apps reach **$1k/month**; **only 4.6%** of new apps reach **$10k/month ($120k ARR) within 2 years**; median app makes **<$50/month**. Annual plans retain **30%** at year 1 vs **11.4%** monthly. *(RevenueCat 2024/25)*
**Conclusion: $1M ARR requires stacking multiple rails, not a single B2C subscription.**

## The revenue mix (layered, with real anchors)

### Rail 1 — Institutional licensing (the most reliable $1M path)
Sell the tool to departments/colleges; the **institution pays so students see no paywall** — which is exactly the no-paywall classroom experience we want, funded by the buyer. This is bottoms-up edtech (faculty pilot → dept/dean → license).
- **Anchors:** Top Hat institutional **$10/student/semester** (negotiated, vs $33 retail; dept/institution = custom pricing). *(tophat.com; uiowa.edu)* Ground News group seats **$50–100/user/year** (bulk $4.16/mo = $50/yr at 10+ seats). *(ground.news/group-subscriptions)*
- **(rec)** Politiface institutional target **~$3–8/student/year** (civic prep is lighter than courseware). A college with ~5,000 affected students × $5 = **~$25k/deal**; ~40 Florida public institutions → a **$0.5–1M** ceiling in FL alone.
- **Distribution rail that exists:** "inclusive access" / Barnes & Noble "First Day" auto-bills digital materials as a per-course charge to the student account. *(ucf.edu First Day)* A path in, though it's student-paid via course fee.
- The free **synchronous Live Class Game** is the demo that closes these.

### Rail 2 — B2C "Civic Agency" Plus (subscription; scales with the repositioning)
The empowerment framing **expands the TAM from "FL exam-takers" to "every politically-anxious citizen"** — which is what makes B2C worth it despite low conversion %, because the free-user denominator becomes huge. **Ground News is live proof a nonpartisan "see through the spin" subscription works B2C** (3 tiers, ~$40/yr Premium). *(ground.news/subscribe)*
- **(rec)** Plus **$9.99/mo · ~$39.99–49.99/yr**, push annual (retention 30% vs 11%). Common points are $9.99/mo & $29.99+/yr (avg $32.53/yr). *(RevenueCat 2024)*
- Plus is branded as **"your civic power"** (depth, the IMDb-of-power, mastery/identity, "you vs. the average citizen"), not "exam tools." Bundles all exam Passes.

### Rail 3 — Foundation / philanthropic grants (non-dilutive; funds the content long-pole)
Civic literacy is **heavily funded**: Knight Foundation (civic tech — $4M+ rounds, $32M news challenges), Carnegie (civic engagement), iCivics (foundation-funded nonprofit civic ed), and a **federal $150M+ civics line (2025)**. *(knightfoundation.org; carnegie.org; icivics.org; npr.org)* For a nonpartisan civic mission, grants can **fund content production** (our real cost) without requiring profit.
- **Structural caveat / open decision:** most civic grants favor nonprofits or fiscal-sponsored / public-benefit structures. Eligibility may require a **nonprofit arm, fiscal sponsor, or PBC** — decide the corporate structure early if we want this money.

### Rail 4 — Exam Passes (de-emphasized → impulse or folded into Plus)
Given low individual WTP + Cambium lock, the FCLE "Pass" is **not** a profit center. **(rec)** Fold FCLE prep into Plus, or price a cheap **~$4.99–9.99** impulse. Transactional upside, not the engine. USCIS/other-state passes later, same logic.

### Rail 5 — Credibility partnerships / sponsorship / B2B2C (secondary on revenue, strategic on trust)
Endorsements, content collaborations, and "informed-citizen" bundles with established nonpartisan civic organizations: the **National Constitution Center, iCivics, public libraries, and immigrant-services / naturalization nonprofits**. Two distinct payoffs. (a) **Credibility:** a co-sign from a recognized civic body de-risks institutional adoption (the president approves a tool trusted names already back) and reinforces, never dilutes, the nonpartisan-trust moat that Rails 1-3 all depend on. (b) **Distribution into an adjacent market:** libraries and naturalization nonprofits reach **USCIS citizenship-test prep** audiences beyond the FCLE wedge, a natural second exam to fold into Plus/Passes. iCivics additionally ties into Rail 3 grant funding. Pursue as logos/endorsements/bundles, not revenue dependencies; vet each partner for strict nonpartisanship first. Opportunistic on money, deliberate on trust.

## One entitlement layer (unchanged, load-bearing)
Capability flags on the user record (`unlimited_energy`, `fcle_prep`, `plus`, `civic_agency`), granted by ANY source — consumable / non-consumable / subscription / **institutional or grant-funded redemption code** — with expiry. **App checks capability only.** Use **RevenueCat**. The same redemption-code rail that comps the professor's class is what an institution or a grant buys at scale. **No-paywall-for-students = the institution/grant is the payer.**

## The energy mechanic (still open: in or out for launch — see Risk)
If used: **gate volume/grind only (Endless), never the daily structured learning + reviews** — a free user can always do their real civic learning. (rec) cap 5, regen +1/30min; refills via Plus / rewarded ad / gems; purchased currency **cannot expire** (Apple 3.1.1). The classroom/faculty optics argue for **launching the cohort with no energy/paywall at all** and adding energy later if retention data justifies it. Duolingo itself rebranded "Hearts"→"Energy" to soften backlash.

## Apple compliance (what gets you rejected)
All paid tiers use IAP: energy = **consumable**, Pass = **non-consumable**, Plus = **auto-renewable subscription** (≥7 days, ongoing/updated value, cross-device). No license-key/QR unlocks. Restore Purchases required. Purchased currency can't expire. **Account & data deletion** required. Register for the **Small Business Program** (15% vs 30%). **Do NOT rely on the US external-purchase-link carve-out at launch** — real post-Epic, but actively litigated/possibly paused into 2026.

## Ethics = the business model (the "Bernays" question, resolved)
Selling a *feeling* (agency, control, identity) is legitimate and powerful — Calm sells calm, Strava sells the athlete-identity, Ground News sells "I see through the spin." But for a civics brand, **the persuasion engine and the moat are the same thing: nonpartisan trust.** Point the desire-engineering at *civic agency and clarity*, **never at a partisan outcome.** Partisanship would destroy the trust asset, institutional sales, AND grant eligibility simultaneously. So nonpartisan rigor isn't a constraint on the model — it *is* the model. Ground News + AllSides prove nonpartisan trust is directly monetizable.

## The 3 highest-leverage bets
1. **Institutional licensing in Florida** (faculty → dept → college), using the free Live Class Game as the demo. The reliable $1M path; the payer is the institution, so students never see a paywall.
2. **The empowerment repositioning** → unlock the mass B2C TAM + a Ground-News-style nonpartisan-trust "Civic Agency" subscription.
3. **Pursue civic-ed grant money** to finance content production (the long pole) — contingent on the corporate-structure decision.

## Biggest risks
1. **Pure B2C can't hit $1M** (benchmarks) → must stack rails.
2. **Cambium lock** → Politiface is prep-only, never the official exam; caps FCLE centrality.
3. **Grant eligibility** may force a nonprofit/PBC/fiscal-sponsor structure → decide early.
4. **Nonpartisan trust is fragile** — one partisan misstep kills the moat + grants + institutional deals.
5. **Content production is the cost and the long pole**; grants are the mitigation.

## Open decisions
1. **Corporate structure** for grant eligibility (for-profit vs nonprofit arm vs PBC/fiscal sponsor).
2. **Institutional price point** (anchor: Top Hat $10/student/sem, Ground News ~$50–100/user/yr; need 1–2 real civic-tool quotes).
3. **B2C Plus** price + the "Civic Agency" branding vs "exam tools."
4. **Energy mechanic** in or out for the v2 launch (leaning: out for the faculty cohort).

## Caveats on the evidence
Quantitative benchmarks lean heavily on one vendor (RevenueCat — de-facto industry source but pro-subscription, cross-category). The 2nd research pass was **partial**: it hit a session rate-limit, so the auto-synthesis and several Ground News/AllSides positioning claims were cut (Ground News *pricing* and core-product claims did verify; positioning is well-established from public pages). Apple external-link status is time-sensitive. Grant *amounts available to a for-profit* specifically were not quantified — verify eligibility before counting on it. Institutional per-student civic-tool pricing is inferred from adjacent tools (Top Hat courseware, Ground News media-literacy), not a direct civic-prep comp — get real quotes.
