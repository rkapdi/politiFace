# FCLE question bank (canonical source)

YAML here is the single source of truth for the server question bank. CI
validates every PR (`scripts/ingest_content.py --check`) and ingests to
Postgres on merge to main under a new `content_version`.

One file per FCLE domain: `american_democracy.yaml`, `us_constitution.yaml`,
`founding_documents.yaml`, `landmark_impact.yaml`.

## Format

```yaml
domain: us_constitution        # must match the file's domain
questions:
  - id: usconst-example-001    # stable slug, never reuse or rename
    stem: >
      The question text students see.
    options:                   # 2 to 6 options, unique keys
      - key: a
        text: First choice
      - key: b
        text: Second choice
    answer: b                  # must be one of the option keys
    explanation: >
      Shown after answering. Cite the source in prose where useful.
    citation: https://constitution.congress.gov/constitution/article-1/
    difficulty: 2              # 1 (easy) to 5 (hard), default 3
    objective: null            # optional objective code from content/fcle/objectives.yaml
    status: draft              # draft | reviewed | published
```

## Rules (enforced by CI)

- `id` is permanent. It maps deterministically to the database UUID, which is
  what student FSRS memory state is keyed on. Renaming an id orphans that
  state; edit content in place instead.
- Every question needs a working `https://` citation to a primary public
  source (constitution.congress.gov, archives.gov, congress.gov,
  federalregister.gov, uscourts.gov, fldoe.org, usa.gov and similar).
  Freely available FCLE sample exams are copyrighted: use them only as a
  style and coverage model, never copy them.
- Only `status: published` questions are served to students or used in
  Mock FCLE assembly. Founder editorial review gates the flip to published,
  at PR review time.
- Neutral, recognition-based, factual. No partisan framing. No em-dashes in
  student-facing text (house style).
- A question removed from YAML is automatically unpublished on the next
  ingest (never deleted; events referencing it stay intact).

## Editorial review flow

`scripts/review_questions.py` is the founder-facing tool for reviewing the
bank and gating the `draft -> reviewed -> published` flip. It reads the same
YAML this file documents and edits nothing but `status:` lines.

pyyaml is not installed against the system `python3` on the build machine, so
run the tool (and the ingest check) through a local venv:

```bash
python3 -m venv .venv
.venv/bin/pip install pyyaml
```

The `.venv/` directory is git-ignored; never commit it.

Three modes:

```bash
# 1. LIST / REVIEW: one compact card per question (id, domain, objective,
#    status, stem, options with the answer marked, explanation, citation).
#    Filter with --domain, --status, --file.
.venv/bin/python scripts/review_questions.py --domain us_constitution --status draft

# 2. COVERAGE REPORT: per-domain published-vs-20 (the Mock FCLE threshold),
#    counts per objective code, and which domains are still below threshold.
.venv/bin/python scripts/review_questions.py --report

# 3. STATUS SETTER: flip status with a MINIMAL in-place edit (only the
#    question's `status:` line changes; block scalars and comments are
#    preserved). Select by --ids and/or --file (and optionally --domain /
#    --status). Preview first with --dry-run.
.venv/bin/python scripts/review_questions.py --dry-run \
    --set-status published --ids usconst-article1-congress-001,landmark-marbury-001
.venv/bin/python scripts/review_questions.py \
    --set-status reviewed --file content/questions/us_constitution.yaml
```

After a status flip, confirm the edit was surgical:

```bash
git diff -- content/questions   # only `status:` lines should differ
.venv/bin/python scripts/ingest_content.py --check   # still passes
```
