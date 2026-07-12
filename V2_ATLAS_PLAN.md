# Atlas as the IMDb of American politics + content at federal scale

*Planning doc, 2026-07-05. For discussion before build. House style: no
em-dashes.*

## What changes

Two connected moves:

1. **Content scale.** From ~45 hand-authored face cards to coverage of
   most of the federal government: all 537 members of Congress, the
   cabinet and cabinet-rank officials, the Supreme Court, and the senior
   Executive Office. Roughly 590 people.
2. **Atlas becomes a reference product, preloaded.** Today the politician
   detail screen fetches a Wikipedia summary at runtime when opened. That
   inverts: every person page ships complete inside the app (facts,
   career timeline, committees, citations), rendered instantly, fully
   offline. IMDb model: rich entity pages, densely cross-linked.

The load-bearing distinction: **Atlas coverage is not deck coverage.**
Everything is in the Atlas as reference; only curated sets become FSRS
decks students memorize. Dumping 590 faces into spaced repetition would
bury the learning experience. The reference layer is comprehensive; the
game layer stays designed.

## Data sources (all public domain or official)

| Data | Source | Verified |
|---|---|---|
| Members of Congress: names, party, state, district, FULL term history since first election, birthday, bioguide + wikidata ids | `unitedstates/congress-legislators` (community-maintained canonical dataset, public domain, updated within days of changes) | Yes: 537 current members, FL delegation = 29, current through the 2026 roster |
| Committee assignments + leadership positions | same repo, `committee-membership-current.yaml` | Same pipeline |
| Member portraits | `unitedstates/images` (official congressional photos, 225x275 available) | Yes: ~46KB each at 225x275, recompressible to ~12-15KB |
| Executive orders | Federal Register API | Already shipped (268 orders) |
| Cabinet, cabinet-rank, EOP, agency heads, SCOTUS | Hand-maintained YAML (no clean single API; ~55 people, changes a few times a year; the existing wikidata portrait fetcher covers photos) | Existing pattern |
| Richer bio prose, sponsored legislation (later) | api.congress.gov (free API key) | Deferred, needs founder signup |

Deliberate non-source: **Wikipedia at runtime goes away.** Career facts
come from the datasets above as structured data; "bio text" is generated
from structure ("Senator from Florida since 2019; previously Governor of
Florida 2011-2019"), which is original text with no license entanglement.
Wins: instant offline pages, no CC BY-SA text inside an MIT repo, a
simpler privacy policy (no runtime fetches about what students browse),
and a stronger trust story (every fact traceable to an official dataset,
not an editable wiki). Wikipedia/Ballotpedia become optional external
"read more" links.

## Architecture

### Content pipeline (same pattern as executive orders)
- `scripts/fetch_legislators.py`: congress-legislators + committee
  membership -> `content/people/legislators.yaml`. Deterministic output,
  auditable diffs, weekly refresh workflow like eo-refresh.
- `content/people/officials.yaml` + `justices.yaml`: hand-maintained
  (cabinet, EOP, agencies, SCOTUS), same schema.
- `scripts/fetch_member_photos.py`: portraits -> recompressed bundled
  thumbnails; CI drift check syncs bundled copies.
- Ingest extends to `public.entities` (type `person`) so the server/web
  Atlas has parity later.

### App
- Schema v12: `people` table (id = bioguide or slug, name, personType,
  currentRole, party, state, district, birthday, portrait, terms JSON,
  committees JSON, citations JSON), seeded by checksum like decks.
- Person page, all local: header (portrait, name, role, party/state),
  fact rows, career timeline from term history, committee list with
  leadership badges, cross-links (institution node, the person's
  executive orders for presidents, "appears in Chapter N"), and source
  links (bioguide.congress.gov, congress.gov member page, official
  site).
- Atlas search extends across all people; filters by chamber, state,
  party.
- `wikipedia_bio_service` retires; the `politician_bios` cache table is
  superseded by `people`.

### Game layer (curated, not exhaustive)
- Existing decks unchanged.
- New auto-generated decks from the same data, opt-in via the deck
  system: **Your State's Delegation** (Florida = 30 cards; the MDC wedge
  deck), **Committee Chairs** (~20), **Senate Leadership**, optionally
  **Full Senate** (100) for completionists.
- A deck-generation script writes deck YAML from people data; no
  hand-authoring 500 cards.

## Sequencing

- **P1 (the core):** fetchers, people schema + seeding, person pages
  preloaded, full Congress in Atlas with search/filters, Florida
  delegation deck, retire runtime Wikipedia, bundled thumbnails.
- **P2:** hand-maintained executive/judicial officials file, president
  page cross-linked to executive orders, deck generation for the other
  curated sets, weekly refresh workflow.
- **P3 (later):** committee pages, state hub pages, api.congress.gov
  enrichment (bio prose, sponsored bills), historical members.

## Decision points (founder input wanted)

1. **App size.** ~590 bundled thumbnails at ~12-15KB is +7-9MB on the
   download. Recommendation: accept it (hybrid: bundled thumbs
   everywhere, network hi-res on the detail page via the existing cached
   image stack). Alternative is network-only portraits, which breaks the
   offline-first story.
2. **House members in decks.** Recommendation: Atlas-only for all 435,
   plus the state-delegation deck (students learn THEIR 30, not all
   435). Confirm.
3. **Retiring runtime Wikipedia.** Recommendation: yes (offline, privacy,
   licensing, trust). The existing politician detail bios get replaced by
   structured career data. Confirm you are comfortable losing the prose
   paragraph until api.congress.gov enrichment lands.
4. **State personalization.** Ship a state picker (default: none chosen,
   Florida first in the list) or hardcode Florida for the pilot?
   Recommendation: picker; it is the same work and makes the app honest
   outside Miami Dade.
5. **api.congress.gov key.** Free signup under your account when we want
   richer bios and legislation data. Not needed for P1.
