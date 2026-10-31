#!/usr/bin/env python3
"""Validate and ingest canonical content YAML into the Supabase Postgres.

Two modes:

  --check            Validate only (no database needed). Run on every PR.
  --db <url>         Validate, then ingest under a new content_version.
                     Run by CI on merge to main with the SUPABASE_DB_URL
                     secret. Idempotent: question ids map to deterministic
                     UUIDs, so re-ingest updates in place and student FSRS
                     state (keyed on those UUIDs) survives content edits.

What it ingests:
  content/questions/*.yaml      -> public.questions + app.question_keys
  content/fcle/objectives.yaml  -> public.objectives
  content/governments/us/government.yaml (nodes) -> public.entities

System questions absent from YAML are unpublished (review_status -> draft),
never deleted: the event log keeps referencing them.

Requires: pyyaml; psycopg (only for ingest mode).
"""

from __future__ import annotations

import argparse
import re
import sys
import uuid
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
QUESTIONS_DIR = REPO / "content" / "questions"
OBJECTIVES_FILE = REPO / "content" / "fcle" / "objectives.yaml"
GOVERNMENT_FILE = REPO / "content" / "governments" / "us" / "government.yaml"
EO_FILE = REPO / "content" / "atlas" / "executive_orders.yaml"
VOCABULARY_FILE = REPO / "content" / "atlas" / "vocabulary.yaml"
PEOPLE_FILE = REPO / "content" / "people" / "legislators.yaml"
ENRICHMENT_FILE = REPO / "content" / "people" / "enrichment.yaml"
LAWS_FILE = REPO / "content" / "atlas" / "recent_laws.yaml"

DOMAINS = {
    "american_democracy": 1,
    "us_constitution": 2,
    "founding_documents": 3,
    "landmark_impact": 4,
}
STATUSES = ("draft", "reviewed", "published")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{2,60}$")
KEY_RE = re.compile(r"^[a-z]$")

# Answer-key hygiene (see check_answer_balance / check_longest_option).
# No single answer letter may key more than this share of a domain's items,
# and the correct option should not be the longest one this often either.
ANSWER_SHARE_MAX = 0.35
ANSWER_BALANCE_MIN_ITEMS = 8
LONGEST_OPTION_SHARE_MAX = 0.35

# The original 80 published items are known to be answer-key unbalanced
# (54 of 80 keyed "a"). They are frozen here so the balance check is an
# ERROR for every newer item but only a WARNING for these. The separate,
# founder-approved answer-key rebalance PR fixes the keys and deletes this
# set; do not add new ids to it.
LEGACY_UNBALANCED_IDS = frozenset({
    "amdem-checks-balances-07",
    "amdem-consent-governed-001",
    "amdem-declaration-govt-purpose-10",
    "amdem-declaration-natural-rights-09",
    "amdem-due-process-06",
    "amdem-electoral-college-electors-06",
    "amdem-federalism-11",
    "amdem-homestead-economic-freedom-12",
    "amdem-judicial-review-origin-01",
    "amdem-limited-government-02",
    "amdem-locke-social-contract-04",
    "amdem-natural-law-locke-05",
    "amdem-original-jurisdiction-states-05",
    "amdem-plessy-brown-segregation-10",
    "amdem-republic-advantage-08",
    "amdem-roman-senate-03",
    "amdem-rule-of-law-01",
    "amdem-separation-powers-001",
    "amdem-supremacy-clause-03",
    "amdem-voting-age-turnout-08",
    "founddocs-articles-amend-01",
    "founddocs-articles-confederation-001",
    "founddocs-articles-league-01",
    "founddocs-articles-notax-01",
    "founddocs-articles-weakness-tax-08",
    "founddocs-billofrights-expand-01",
    "founddocs-consent-governed-ideal-12",
    "founddocs-decl-equality-expand-01",
    "founddocs-decl-unalienable-01",
    "founddocs-english-bill-of-rights-03",
    "founddocs-fed10-faction-01",
    "founddocs-fed14-repvsdem-01",
    "founddocs-fed31-taxation-01",
    "founddocs-fed39-republic-01",
    "founddocs-fed51-ambition-01",
    "founddocs-federalist-purpose-001",
    "founddocs-magna-carta-01",
    "founddocs-mayflower-compact-02",
    "founddocs-northwest-ordinance-07",
    "founddocs-preamble-sovereignty-01",
    "landmark-baker-districting-09",
    "landmark-brown-board-001",
    "landmark-brown-overturns-plessy-07",
    "landmark-dred-scott-citizenship-03",
    "landmark-engel-school-prayer-10",
    "landmark-gideon-counsel-11",
    "landmark-korematsu-exclusion-06",
    "landmark-mapp-exclusionary-08",
    "landmark-marbury-001",
    "landmark-marbury-strike-01",
    "landmark-mcculloch-tax-02",
    "landmark-miranda-rights-12",
    "landmark-nyt-pentagon-papers-01",
    "landmark-plessy-separate-equal-04",
    "landmark-roe-privacy-03",
    "landmark-schenck-speech-05",
    "landmark-texas-johnson-flag-07",
    "landmark-tinker-armbands-13",
    "landmark-us-nixon-privilege-04",
    "landmark-yoder-religion-02",
    "usconst-14th-citizenship-clause-04",
    "usconst-14th-superseded-dredscott-06",
    "usconst-5th-due-process-09",
    "usconst-article1-congress-001",
    "usconst-article5-propose-congress-01",
    "usconst-article5-ratify-states-02",
    "usconst-article5-senate-suffrage-03",
    "usconst-bill-of-rights-count-001",
    "usconst-commander-in-chief-02",
    "usconst-expostfacto-attainder-08",
    "usconst-expressed-powers-07",
    "usconst-federal-court-tiers-10",
    "usconst-good-behavior-tenure-05",
    "usconst-habeas-corpus-07",
    "usconst-house-terms-10",
    "usconst-impeachment-house-senate-12",
    "usconst-judicial-vesting-04",
    "usconst-naturalization-power-05",
    "usconst-origination-clause-11",
    "usconst-president-qualifications-01",
})

# Deterministic ids: the same YAML id always lands on the same row.
NS = uuid.uuid5(uuid.NAMESPACE_URL, "politiface.app/content")


def qid_uuid(qid: str) -> uuid.UUID:
    return uuid.uuid5(NS, f"question:{qid}")


def objective_uuid(code: str) -> uuid.UUID:
    return uuid.uuid5(NS, f"objective:{code}")


def entity_uuid(etype: str, slug: str) -> uuid.UUID:
    return uuid.uuid5(NS, f"entity:{etype}:{slug}")


class Errors:
    def __init__(self) -> None:
        self.items: list[str] = []

    def add(self, where: str, msg: str) -> None:
        self.items.append(f"{where}: {msg}")

    def bail_if_any(self) -> None:
        if self.items:
            for e in self.items:
                print(f"ERROR {e}", file=sys.stderr)
            sys.exit(1)


class Warnings:
    """Non-fatal findings: printed, never fail the run."""

    def __init__(self) -> None:
        self.items: list[str] = []

    def add(self, where: str, msg: str) -> None:
        self.items.append(f"{where}: {msg}")

    def print_all(self) -> None:
        for w in self.items:
            print(f"WARNING {w}", file=sys.stderr)


def load_objectives(errors: Errors) -> list[dict]:
    if not OBJECTIVES_FILE.exists():
        return []
    doc = yaml.safe_load(OBJECTIVES_FILE.read_text()) or {}
    objectives = doc.get("objectives") or []
    seen: set[str] = set()
    for i, o in enumerate(objectives):
        where = f"{OBJECTIVES_FILE.name}[{i}]"
        code = o.get("code")
        if not code or not isinstance(code, str):
            errors.add(where, "missing code")
            continue
        if code in seen:
            errors.add(where, f"duplicate objective code {code!r}")
        seen.add(code)
        if o.get("domain") not in DOMAINS:
            errors.add(where, f"unknown domain {o.get('domain')!r}")
        if not (o.get("description") or "").strip():
            errors.add(where, "missing description")
    return objectives


def load_questions(errors: Errors, objective_codes: set[str]) -> list[dict]:
    questions: list[dict] = []
    seen_ids: set[str] = set()
    files = sorted(QUESTIONS_DIR.glob("*.yaml"))
    if not files:
        errors.add(str(QUESTIONS_DIR), "no question files found")
        return []

    for path in files:
        doc = yaml.safe_load(path.read_text()) or {}
        domain = doc.get("domain")
        if domain not in DOMAINS:
            errors.add(path.name, f"unknown or missing domain {domain!r}")
            continue

        for i, q in enumerate(doc.get("questions") or []):
            where = f"{path.name}[{i}]"
            qid = q.get("id")
            if not qid or not ID_RE.match(str(qid)):
                errors.add(where, f"bad id {qid!r} (want slug like usconst-topic-001)")
                continue
            where = f"{path.name}:{qid}"
            if qid in seen_ids:
                errors.add(where, "duplicate question id")
            seen_ids.add(qid)

            stem = (q.get("stem") or "").strip()
            if len(stem) < 10:
                errors.add(where, "stem missing or too short")
            if "—" in stem or "—" in (q.get("explanation") or ""):
                errors.add(where, "em-dash in student-facing text (house style)")

            options = q.get("options") or []
            keys = [o.get("key") for o in options if isinstance(o, dict)]
            if not (2 <= len(options) <= 6):
                errors.add(where, f"need 2-6 options, got {len(options)}")
            if len(set(keys)) != len(keys):
                errors.add(where, "duplicate option keys")
            for k in keys:
                if not k or not KEY_RE.match(str(k)):
                    errors.add(where, f"bad option key {k!r} (single lowercase letter)")
            for o in options:
                if not (isinstance(o, dict) and (o.get("text") or "").strip()):
                    errors.add(where, "option missing text")

            answer = q.get("answer")
            if answer not in keys:
                errors.add(where, f"answer {answer!r} is not an option key")

            if not (q.get("explanation") or "").strip():
                errors.add(where, "missing explanation")

            citation = (q.get("citation") or "").strip()
            if not citation.startswith("https://"):
                errors.add(where, "citation must be a working https:// URL")

            difficulty = q.get("difficulty", 3)
            if not isinstance(difficulty, int) or not 1 <= difficulty <= 5:
                errors.add(where, f"difficulty {difficulty!r} out of range 1-5")

            status = q.get("status", "draft")
            if status not in STATUSES:
                errors.add(where, f"bad status {status!r}")

            objective = q.get("objective")
            if objective is not None and objective not in objective_codes:
                errors.add(where, f"unknown objective code {objective!r}")

            questions.append(
                {
                    "id": qid,
                    "domain_id": DOMAINS[domain],
                    "stem": stem,
                    "options": options,
                    "answer": answer,
                    "explanation": (q.get("explanation") or "").strip(),
                    "citation": citation,
                    "difficulty": difficulty,
                    "status": status,
                    "objective": objective,
                }
            )
    return questions


def _by_domain(questions: list[dict]) -> dict[str, list[dict]]:
    names = {v: k for k, v in DOMAINS.items()}
    grouped: dict[str, list[dict]] = {}
    for q in questions:
        grouped.setdefault(names[q["domain_id"]], []).append(q)
    return grouped


def answer_share_violations(
    questions: list[dict], max_share: float = ANSWER_SHARE_MAX
) -> list[tuple[str, int, int]]:
    """(letter, count, total) for every answer letter above max_share."""
    total = len(questions)
    if not total:
        return []
    counts: dict[str, int] = {}
    for q in questions:
        counts[q["answer"]] = counts.get(q["answer"], 0) + 1
    return [
        (letter, n, total)
        for letter, n in sorted(counts.items())
        if n / total > max_share
    ]


def check_answer_balance(
    questions: list[dict], errors: Errors, warnings: Warnings,
    legacy_ids: frozenset[str] = LEGACY_UNBALANCED_IDS,
) -> None:
    """Per domain, no answer letter may key more than ANSWER_SHARE_MAX.

    ERROR for items outside legacy_ids (once a domain has at least
    ANSWER_BALANCE_MIN_ITEMS of them); WARNING for the frozen legacy items.
    """
    for domain, qs in sorted(_by_domain(questions).items()):
        current = [q for q in qs if q["id"] not in legacy_ids]
        legacy = [q for q in qs if q["id"] in legacy_ids]
        for sink, label, group in (
            (errors, "", current),
            (warnings, "legacy ", legacy),
        ):
            if len(group) < ANSWER_BALANCE_MIN_ITEMS:
                continue
            for letter, n, total in answer_share_violations(group):
                sink.add(
                    domain,
                    f"answer {letter!r} keys {n}/{total} {label}items "
                    f"({n / total:.0%}); max {ANSWER_SHARE_MAX:.0%} per letter",
                )


def correct_is_longest(q: dict) -> bool:
    """True when the keyed option is the longest (ties count)."""
    lengths = {
        o.get("key"): len((o.get("text") or "").strip())
        for o in q["options"] if isinstance(o, dict)
    }
    if q["answer"] not in lengths:
        return False
    return lengths[q["answer"]] == max(lengths.values())


def check_longest_option(questions: list[dict], warnings: Warnings) -> None:
    """Warn when the correct option is the longest in too many items."""
    for domain, qs in sorted(_by_domain(questions).items()):
        n = sum(1 for q in qs if correct_is_longest(q))
        if qs and n / len(qs) > LONGEST_OPTION_SHARE_MAX:
            warnings.add(
                domain,
                f"correct option is the longest (ties count) in "
                f"{n}/{len(qs)} items ({n / len(qs):.0%}); "
                f"max {LONGEST_OPTION_SHARE_MAX:.0%}",
            )

def load_entities(errors: Errors) -> list[dict]:
    entities: list[dict] = []

    if GOVERNMENT_FILE.exists():
        doc = yaml.safe_load(GOVERNMENT_FILE.read_text()) or {}
        for i, node in enumerate(doc.get("nodes") or []):
            where = f"{GOVERNMENT_FILE.name}[{i}]"
            slug = node.get("id")
            if not slug:
                errors.add(where, "node missing id")
                continue
            etype = node.get("node_type") or "institution"
            data = {
                k: v
                for k, v in node.items()
                if k not in ("id", "name", "map", "unlock_requires")
            }
            entities.append({
                "type": etype, "slug": slug,
                "name": node.get("name") or slug,
                "data": data, "citations": [],
            })

    if EO_FILE.exists():
        doc = yaml.safe_load(EO_FILE.read_text()) or {}
        for i, o in enumerate(doc.get("orders") or []):
            where = f"{EO_FILE.name}[{i}]"
            number = o.get("eo_number")
            if not isinstance(number, int):
                errors.add(where, f"bad eo_number {number!r}")
                continue
            url = (o.get("url") or "").strip()
            if not url.startswith("https://www.federalregister.gov/"):
                errors.add(where, "url must be a federalregister.gov link")
            if not (o.get("title") or "").strip():
                errors.add(where, "missing title")
            entities.append({
                "type": "executive_order",
                "slug": f"eo-{number}",
                "name": o.get("title") or f"Executive Order {number}",
                "data": {
                    "eo_number": number,
                    "president": o.get("president"),
                    "signing_date": o.get("signing_date"),
                    "federal_register_citation":
                        o.get("federal_register_citation"),
                    "document_number": o.get("document_number"),
                    "abstract": o.get("abstract"),
                },
                "citations": [url],
            })

    if VOCABULARY_FILE.exists():
        doc = yaml.safe_load(VOCABULARY_FILE.read_text()) or {}
        for i, t in enumerate(doc.get("terms") or []):
            tid = t.get("id")
            where = f"{VOCABULARY_FILE.name}[{i}]"
            if not tid or not ID_RE.match(str(tid)):
                errors.add(where, f"bad term id {tid!r}")
                continue
            where = f"{VOCABULARY_FILE.name}:{tid}"
            if len((t.get("definition") or "").strip()) < 20:
                errors.add(where, "definition missing or too short")
            citation = (t.get("citation") or "").strip()
            if not citation.startswith("https://"):
                errors.add(where, "citation must be a working https:// URL")
            domain = t.get("domain")
            if domain is not None and domain not in DOMAINS:
                errors.add(where, f"unknown domain {domain!r}")
            if "—" in (t.get("definition") or ""):
                errors.add(where, "em-dash in student-facing text (house style)")
            entities.append({
                "type": "term",
                "slug": str(tid),
                "name": (t.get("term") or "").strip() or str(tid),
                "data": {
                    "definition": (t.get("definition") or "").strip(),
                    "domain": domain,
                },
                "citations": [citation],
            })

    if LAWS_FILE.exists():
        doc = yaml.safe_load(LAWS_FILE.read_text()) or {}
        for i, l in enumerate(doc.get("laws") or []):
            where = f"{LAWS_FILE.name}[{i}]"
            number = l.get("law_number")
            if not number:
                errors.add(where, "law missing law_number")
                continue
            url = (l.get("url") or "").strip()
            if not url.startswith("https://www.congress.gov/"):
                errors.add(where, "url must be a congress.gov link")
            entities.append({
                "type": "law",
                "slug": f"pl-{number}",
                "name": (l.get("title") or f"Public Law {number}").strip(),
                "data": {
                    k: l.get(k)
                    for k in ("law_number", "bill", "enacted_date",
                              "origin_chamber", "sponsor")
                },
                "citations": [url],
            })

    enrichment_by_id: dict = {}
    if ENRICHMENT_FILE.exists():
        doc = yaml.safe_load(ENRICHMENT_FILE.read_text()) or {}
        enrichment_by_id = doc.get("members") or {}

    if PEOPLE_FILE.exists():
        doc = yaml.safe_load(PEOPLE_FILE.read_text()) or {}
        for i, p in enumerate(doc.get("people") or []):
            where = f"{PEOPLE_FILE.name}[{i}]"
            bioguide = p.get("id")
            if not bioguide:
                errors.add(where, "person missing id")
                continue
            if p.get("chamber") not in ("senate", "house"):
                errors.add(f"{PEOPLE_FILE.name}:{bioguide}",
                           f"bad chamber {p.get('chamber')!r}")
            citations = p.get("citations") or []
            if not citations:
                errors.add(f"{PEOPLE_FILE.name}:{bioguide}", "no citations")
            entities.append({
                "type": "person",
                "slug": str(bioguide),
                "name": p.get("name") or str(bioguide),
                "data": {
                    **{
                        k: p.get(k)
                        for k in ("chamber", "state", "district", "party",
                                  "birthday", "wikidata", "current_term",
                                  "terms", "committees")
                    },
                    "extras": enrichment_by_id.get(bioguide) or {},
                },
                "citations": citations,
            })

    return entities


def ingest(db_url: str, version: str, git_sha: str | None,
           objectives: list[dict], questions: list[dict],
           entities: list[dict]) -> None:
    import json

    import psycopg

    with psycopg.connect(db_url) as conn, conn.cursor() as cur:
        cur.execute(
            "insert into public.content_versions (version, git_sha)"
            " values (%s, %s) returning id",
            (version, git_sha),
        )
        version_id = cur.fetchone()[0]

        for o in objectives:
            cur.execute(
                """
                insert into public.objectives (id, domain_id, code, description)
                values (%s, %s, %s, %s)
                on conflict (code) do update set
                  domain_id = excluded.domain_id,
                  description = excluded.description
                """,
                (str(objective_uuid(o["code"])), DOMAINS[o["domain"]],
                 o["code"], o["description"].strip()),
            )

        for q in questions:
            cur.execute(
                """
                insert into public.questions
                  (id, domain_id, objective_id, difficulty, stem, options,
                   citation, author, review_status, content_version_id)
                values
                  (%s, %s, %s, %s, %s, %s, %s, 'system', 'draft', %s)
                on conflict (id) do update set
                  domain_id = excluded.domain_id,
                  objective_id = excluded.objective_id,
                  difficulty = excluded.difficulty,
                  stem = excluded.stem,
                  options = excluded.options,
                  citation = excluded.citation,
                  content_version_id = excluded.content_version_id
                """,
                (str(qid_uuid(q["id"])), q["domain_id"],
                 str(objective_uuid(q["objective"])) if q["objective"] else None,
                 q["difficulty"], q["stem"], json.dumps(q["options"]),
                 q["citation"], version_id),
            )
            cur.execute(
                """
                insert into app.question_keys (question_id, answer_key, explanation)
                values (%s, %s, %s)
                on conflict (question_id) do update set
                  answer_key = excluded.answer_key,
                  explanation = excluded.explanation
                """,
                (str(qid_uuid(q["id"])), q["answer"], q["explanation"]),
            )
            # Status last: the publish trigger checks the key row exists.
            cur.execute(
                "update public.questions set review_status = %s where id = %s",
                (q["status"], str(qid_uuid(q["id"]))),
            )

        # Unpublish system questions that left the YAML (keep rows: events
        # reference them).
        current_ids = [str(qid_uuid(q["id"])) for q in questions]
        cur.execute(
            """
            update public.questions set review_status = 'draft'
            where author = 'system' and review_status <> 'draft'
              and not (id = any(%s::uuid[]))
            """,
            (current_ids,),
        )
        unpublished = cur.rowcount

        for e in entities:
            cur.execute(
                """
                insert into public.entities
                  (id, type, slug, name, data, citations, content_version_id)
                values (%s, %s, %s, %s, %s, %s, %s)
                on conflict (type, slug) do update set
                  name = excluded.name,
                  data = excluded.data,
                  citations = excluded.citations,
                  content_version_id = excluded.content_version_id
                """,
                (str(entity_uuid(e["type"], e["slug"])), e["type"], e["slug"],
                 e["name"], json.dumps(e["data"]),
                 json.dumps(e.get("citations", [])), version_id),
            )

        conn.commit()
        print(
            f"ingested content_version={version} ({version_id}): "
            f"{len(questions)} questions, {len(objectives)} objectives, "
            f"{len(entities)} entities, {unpublished} unpublished"
        )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="validate only")
    mode.add_argument("--db", help="Postgres URL; validate then ingest")
    ap.add_argument("--version", default=None, help="content version label")
    ap.add_argument("--git-sha", default=None)
    args = ap.parse_args()

    errors = Errors()
    objectives = load_objectives(errors)
    objective_codes = {o.get("code") for o in objectives}
    questions = load_questions(errors, objective_codes)
    warnings = Warnings()
    check_answer_balance(questions, errors, warnings)
    check_longest_option(questions, warnings)
    entities = load_entities(errors)
    warnings.print_all()
    errors.bail_if_any()

    by_status: dict[str, int] = {}
    for q in questions:
        by_status[q["status"]] = by_status.get(q["status"], 0) + 1
    print(
        f"valid: {len(questions)} questions {by_status}, "
        f"{len(objectives)} objectives, {len(entities)} entities"
    )

    if args.db:
        version = args.version or "manual"
        ingest(args.db, version, args.git_sha, objectives, questions, entities)


if __name__ == "__main__":
    main()
