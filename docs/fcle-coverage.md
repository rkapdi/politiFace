# FCLE blueprint and content coverage

What the exam actually tests, where that is written down, and how far our content
is from covering it. This is the working document for the content program.

## Why this exists

Students do not lack FCLE study material. Miami Dade runs a free three-hour boot
camp on seven campuses, maintains a librarian-curated resource guide, and points
students at a free Canvas course, Modern States, and a practice test. What no
resource gives them is a *boundary*: a precise statement of what is on the exam,
against which a student can measure themselves and decide they are ready. Our
own beta user's failure mode was exactly this — determined to prepare, unable to
tell when preparation was complete, deferred the exam indefinitely.

The boundary exists. It is just not where students look.

## The blueprint

The FCLE has **no objective codes of its own**. What it has is the FLDOE
*Supplemental Guide for the Florida Civic Literacy Examination* (Office of
Assessment, 31 March 2022, 10pp). The guide names the four competencies, breaks
each into topics, and — the part nobody uses — hyperlinks those topics to the
Florida K-12 benchmarks that carry them, on CPALMS, the state's official
standards database.

Those 32 benchmarks are the real, citable objectives. They are transcribed with
their official codes in [`content/fcle/objectives.yaml`](../content/fcle/objectives.yaml).

| Source | Where |
| --- | --- |
| Supplemental Guide (the blueprint) | `fldoe.org/core/fileparse.php/5663/urlt/SuppGuideFCLE.pdf` |
| Official Sample Items (40 items + key) | `fldoe.org/core/fileparse.php/5663/urlt/FCLESampleItem.pdf` |
| Rule 6A-10.02413, F.A.C. | `law.cornell.edu/regulations/florida/Fla-Admin-Code-Ann-R-6A-10-02413` |
| Benchmark detail | `cpalms.org/PreviewStandard/Preview/<id>` (ids in `objectives.yaml`) |

`fldoe.org` blocks automated fetches; the Wayback Machine serves both PDFs.

## Copyright — read before authoring

The Supplemental Guide and the Sample Items are FLDOE copyright, and the guide's
own notice **withholds permission for commercial reproduction**. Politiface is a
commercial product with a public repository. Therefore:

- **Do not** commit either PDF, or its text, to this repo.
- **Do not** ingest the 40 official sample items into the question bank. They are
  calibration reference for item style, stimulus type, and difficulty. Nothing more.
- **Do** use benchmark codes (`SS.912.CG.1.1`) freely — identifiers are facts.
- **Do** use case names, document names, and dates freely — also facts.
- **Do** write every question, description, and explanation from primary sources,
  cited. Existing practice already requires a working `.gov` citation per item.

## Exam shape

80 four-option multiple-choice items, roughly 20 per competency (~25% each). One
160-minute session. Fixed form, not adaptive. Passing is 48/80 (60%). Items reflect
Webb's Depth of Knowledge and may be plain recall or built on a stimulus — a quoted
primary source, a chart, or a scenario. Sub-domain item counts and difficulty targets
are **not** published; ~25% per domain is the finest published distribution.

At Miami Dade the exam is a graduation requirement for all degree-seeking students,
and passing the associated course does *not* satisfy it. Reported statewide
high-school pass rates have run in the high thirties to high forties percent;
postsecondary rates run considerably higher.

## What is in scope

**Competency One — American Democracy.** Fifteen named principles: social contract,
checks and balances, rule of law, due process, equality under law, popular
sovereignty, natural rights, federalism, individual liberty, republicanism,
constitutionalism, majority rule with minority rights, equal protection, the Bill of
Rights, and elections. 14 benchmarks.

**Competency Two — United States Constitution.** The seven Articles; the amendment
process and selective incorporation; Federalists versus Anti-Federalists; and eight
named clauses — Supremacy, Full Faith and Credit, Commerce, Emoluments, Due Process,
Equal Protection, Necessary and Proper, and the First Amendment clauses. 8 benchmarks.

**Competency Three — Founding Documents.** Seven core documents and six antecedents,
listed below. The guide names five Federalist Papers specifically: **10, 14, 31, 39,
51**. 5 benchmarks.

**Competency Four — Landmark Impact.** A closed list of **26 Supreme Court cases**,
plus landmark legislation and landmark executive actions given as *categories with
examples* rather than closed lists. 5 benchmarks.

## Coverage: the 26 landmark cases

The single largest gap. There is no `type: case` entity, no landmark-cases deck, and
no card for any of these. Where a case name appears today it is a passing mention
inside a curriculum lesson, `vocabulary.yaml`, or `branch_info.yaml` — nothing a
student can study or be scheduled on. Competency Four is a quarter of the exam.

| # | Case | Year | Card | Question |
| --- | --- | --- | --- | --- |
| 1 | Marbury v. Madison | 1803 | — | — |
| 2 | McCulloch v. Maryland | 1819 | — | — |
| 3 | Dred Scott v. Sandford | 1857 | — | — |
| 4 | Plessy v. Ferguson | 1896 | — | — |
| 5 | Schenck v. United States | 1919 | — | — |
| 6 | Korematsu v. United States | 1944 | — | — |
| 7 | Brown v. Board of Education | 1954 | — | — |
| 8 | Mapp v. Ohio | 1961 | — | — |
| 9 | Baker v. Carr | 1962 | — | — |
| 10 | Engel v. Vitale | 1962 | — | — |
| 11 | Gideon v. Wainwright | 1963 | — | — |
| 12 | Miranda v. Arizona | 1966 | — | — |
| 13 | Tinker v. Des Moines | 1969 | — | — |
| 14 | New York Times v. United States | 1971 | — | — |
| 15 | Wisconsin v. Yoder | 1972 | — | — |
| 16 | Roe v. Wade | 1973 | — | — |
| 17 | United States v. Nixon | 1974 | — | — |
| 18 | Regents of the Univ. of California v. Bakke | 1978 | — | — |
| 19 | Hazelwood v. Kuhlmeier | 1988 | — | — |
| 20 | Texas v. Johnson | 1989 | — | — |
| 21 | Shaw v. Reno | 1993 | — | — |
| 22 | United States v. Lopez | 1995 | — | — |
| 23 | Bush v. Gore | 2000 | — | — |
| 24 | District of Columbia v. Heller | 2008 | — | — |
| 25 | McDonald v. Chicago | 2010 | — | — |
| 26 | Citizens United v. FEC | 2010 | — | — |

`SS.8.A.4.13` additionally names Gibbons v. Ogden (1824), Cherokee Nation v. Georgia
(1831), and Worcester v. Georgia (1832).

Every case has an Oyez summary, and most have an `archives.gov` milestone-document
page — both acceptable citations.

## Coverage: founding documents

Core: Declaration of Independence (1776) · Constitution of Massachusetts (1780) ·
Articles of Confederation (1781) · Northwest Ordinances (1784, 1785, 1787) ·
Federalist Papers 10, 14, 31, 39, 51 · United States Constitution (1787) ·
Bill of Rights (1791).

Antecedents: Magna Carta (1215) · Mayflower Compact (1620) · English Bill of Rights
(1689) · Common Sense (1776) · Virginia Declaration of Rights (1776) ·
Anti-Federalist Papers (e.g. Brutus 1).

`us-concepts-founding.yaml` and `us-concepts-constitution.yaml` already cover the
Declaration, the Articles, the Federalist Papers as a set, the Constitutional
Convention, and the Bill of Rights. The Massachusetts Constitution, the Northwest
Ordinances, Magna Carta, the Mayflower Compact, the English Bill of Rights, Common
Sense, the Virginia Declaration of Rights, and Brutus 1 have no content. The five
named Federalist Papers are not individually covered.

## Coverage: question bank

Eight questions, two per domain, **all `status: draft`**. Nothing is published.

Both `assemble_mock` (server) and `QuestionBankLoader` (bundled) require **20
published questions per domain**, so no mock exam can currently be assembled by
either path. The 80-question mock, the readiness indicator, and weak-area practice
are all built and all starved.

Minimum to light up the mock: **80 published questions, 20 per domain.** A defensible
target is roughly 5–8 items per benchmark, which bounds the job at ~160–250 items —
bounded by the objective list rather than by a round number.

## What to do next

1. Publish a first tranche of 80 questions, 20 per domain, each tagged to a benchmark
   code from `objectives.yaml` and each carrying a primary-source citation. This alone
   turns the existing mock, readiness, and practice screens on.
2. Author the 26 landmark cases as first-class content. This is the largest gap and
   the most citable material we have — Oyez and `archives.gov` cover all of it.
3. Fill the founding-document gaps, and split the Federalist Papers into the five
   the guide names.
4. Surface the blueprint *in the app*. The competency checklist with per-objective
   readiness is the product: it is the boundary and the verdict that no free resource
   provides. `user_domain_readiness` already tracks this at domain granularity and
   needs to go to objective granularity.
5. Ask Professor Purcell to review the blueprint and the coverage table. He is the
   right reviewer, and it gives him something concrete to react to.
