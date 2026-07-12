#!/usr/bin/env python3
"""Editorial-review workflow for the FCLE question bank.

A founder-facing companion to ``scripts/ingest_content.py``. It reads the
canonical YAML in ``content/questions/*.yaml`` (one file per FCLE domain) and
lets you review questions, see how far the bank is from unlocking the Mock
FCLE, and flip a question's ``status`` (draft -> reviewed -> published).

Three modes:

  (default)   LIST/REVIEW  print a compact card per question, with filters.
  --report    COVERAGE      per-domain published-vs-threshold + per-objective.
  --set-status STATUS       flip status with a MINIMAL in-place text edit
                            (only the ``status:`` line is touched; block
                            scalars, comments and formatting are preserved).

Only ``status: published`` questions are served or used in Mock FCLE assembly,
so the report tells you exactly how many more published questions each domain
needs to reach the 20/domain Mock threshold.

Requires pyyaml, which is NOT installed against the system python3 on this
machine. Create a venv once and run the tool through it:

    python3 -m venv .venv
    .venv/bin/pip install pyyaml
    .venv/bin/python scripts/review_questions.py --report

(The .venv directory is already git-ignored; never commit it.)

Examples:

    # Review every draft question in the constitution domain
    .venv/bin/python scripts/review_questions.py \\
        --domain us_constitution --status draft

    # See how far the bank is from unlocking the Mock FCLE
    .venv/bin/python scripts/review_questions.py --report

    # Mark two reviewed questions as published
    .venv/bin/python scripts/review_questions.py \\
        --set-status published --ids usconst-article1-congress-001,landmark-marbury-001

    # Promote a whole file to reviewed (preview first with --dry-run)
    .venv/bin/python scripts/review_questions.py --dry-run \\
        --set-status reviewed --file content/questions/us_constitution.yaml
"""

from __future__ import annotations

import argparse
import re
import sys
import textwrap
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
QUESTIONS_DIR = REPO / "content" / "questions"
OBJECTIVES_FILE = REPO / "content" / "fcle" / "objectives.yaml"

# Kept in sync with scripts/ingest_content.py.
DOMAINS = {
    "american_democracy": 1,
    "us_constitution": 2,
    "founding_documents": 3,
    "landmark_impact": 4,
}
DOMAIN_LABELS = {
    "american_democracy": "American Democracy",
    "us_constitution": "United States Constitution",
    "founding_documents": "Founding Documents",
    "landmark_impact": "Landmark Influences & Supreme Court Cases",
}
STATUSES = ("draft", "reviewed", "published")

# Mock FCLE assembly draws published questions per domain; below this a domain
# cannot contribute a full slice and the mock stays locked.
MOCK_THRESHOLD = 20

# Locates a question list item and its status line in raw YAML text.
ID_LINE_RE = re.compile(r"^(\s*)-\s+id:\s*(?:['\"])?([^'\"\s#]+)")
STATUS_LINE_RE = re.compile(r"^(\s*status:\s*)(\S+)(.*)$")


# --------------------------------------------------------------------------
# Loading
# --------------------------------------------------------------------------
def question_files(file_filter: str | None) -> list[Path]:
    if file_filter:
        p = Path(file_filter)
        if not p.is_absolute():
            # Accept either a repo-relative path or a bare filename.
            cand = REPO / file_filter
            p = cand if cand.exists() else (QUESTIONS_DIR / Path(file_filter).name)
        if not p.exists():
            sys.exit(f"error: file not found: {file_filter}")
        return [p]
    return sorted(QUESTIONS_DIR.glob("*.yaml"))


def load_objectives() -> dict[str, dict]:
    """Return {code: {domain, description}}; empty if the file is absent/blank."""
    if not OBJECTIVES_FILE.exists():
        return {}
    doc = yaml.safe_load(OBJECTIVES_FILE.read_text()) or {}
    out: dict[str, dict] = {}
    for o in doc.get("objectives") or []:
        code = o.get("code")
        if code:
            out[code] = {
                "domain": o.get("domain"),
                "description": (o.get("description") or "").strip(),
            }
    return out


def load_questions(paths: list[Path]) -> list[dict]:
    questions: list[dict] = []
    for path in paths:
        doc = yaml.safe_load(path.read_text()) or {}
        domain = doc.get("domain")
        for q in doc.get("questions") or []:
            questions.append(
                {
                    "file": path,
                    "domain": domain,
                    "id": q.get("id"),
                    "stem": (q.get("stem") or "").strip(),
                    "options": q.get("options") or [],
                    "answer": q.get("answer"),
                    "explanation": (q.get("explanation") or "").strip(),
                    "citation": (q.get("citation") or "").strip(),
                    "difficulty": q.get("difficulty", 3),
                    "objective": q.get("objective"),
                    "status": q.get("status", "draft"),
                }
            )
    return questions


def apply_filters(
    questions: list[dict],
    domain: str | None,
    status: str | None,
    ids: set[str] | None,
) -> list[dict]:
    out = questions
    if domain:
        out = [q for q in out if q["domain"] == domain]
    if status:
        out = [q for q in out if q["status"] == status]
    if ids is not None:
        out = [q for q in out if q["id"] in ids]
    return out


# --------------------------------------------------------------------------
# LIST / REVIEW view
# --------------------------------------------------------------------------
def _wrap(text: str, indent: str) -> str:
    text = " ".join(text.split())
    return textwrap.fill(
        text, width=78, initial_indent=indent, subsequent_indent=indent
    )


def print_cards(questions: list[dict], objectives: dict[str, dict]) -> None:
    if not questions:
        print("(no questions match the given filters)")
        return
    for q in questions:
        print("=" * 80)
        obj = q["objective"]
        obj_label = obj if obj else "(none)"
        if obj and obj in objectives:
            obj_label = f"{obj} - {objectives[obj]['description']}"
        print(f"{q['id']}   [{q['status']}]")
        print(
            f"  domain: {DOMAIN_LABELS.get(q['domain'], q['domain'])}"
            f"   difficulty: {q['difficulty']}"
        )
        print(f"  objective: {obj_label}")
        print()
        print(_wrap(q["stem"], "  "))
        print()
        for o in q["options"]:
            key = o.get("key")
            mark = "->" if key == q["answer"] else "  "
            print(_wrap(f"{mark} {key}) {o.get('text', '')}", "  "))
        print()
        print(_wrap(f"explanation: {q['explanation']}", "  "))
        print(f"  citation: {q['citation']}")
        print()
    print("=" * 80)
    print(f"{len(questions)} question(s)")


# --------------------------------------------------------------------------
# COVERAGE report
# --------------------------------------------------------------------------
def print_report(questions: list[dict], objectives: dict[str, dict]) -> None:
    print("FCLE question bank coverage")
    print(f"Mock FCLE threshold: {MOCK_THRESHOLD} published questions per domain")
    print("=" * 80)

    total_published = 0
    domains_below = 0
    for domain in DOMAINS:
        qs = [q for q in questions if q["domain"] == domain]
        by_status = {s: sum(1 for q in qs if q["status"] == s) for s in STATUSES}
        published = by_status["published"]
        total_published += published
        needed = max(0, MOCK_THRESHOLD - published)
        flag = f"  BELOW THRESHOLD (needs {needed} more)" if needed else "  OK"
        if needed:
            domains_below += 1

        print()
        print(f"{DOMAIN_LABELS.get(domain, domain)}  [{domain}]")
        print(
            f"  published {published}/{MOCK_THRESHOLD}"
            f"   (draft {by_status['draft']}, reviewed {by_status['reviewed']},"
            f" total {len(qs)}){flag}"
        )

        # Per-objective counts within the domain.
        by_obj: dict[str, dict[str, int]] = {}
        for q in qs:
            code = q["objective"] or "(none)"
            slot = by_obj.setdefault(code, {"total": 0, "published": 0})
            slot["total"] += 1
            if q["status"] == "published":
                slot["published"] += 1
        print("  by objective:")
        for code in sorted(by_obj):
            desc = ""
            if code in objectives:
                desc = f"  {objectives[code]['description']}"
            c = by_obj[code]
            print(f"    {code}: {c['published']} published / {c['total']} total{desc}")

    print()
    print("=" * 80)
    print(
        f"total published: {total_published}"
        f"   domains below threshold: {domains_below}/{len(DOMAINS)}"
    )
    if domains_below:
        print("Mock FCLE is LOCKED until every domain reaches the threshold.")
    else:
        print("All domains meet the threshold: Mock FCLE can be assembled.")


# --------------------------------------------------------------------------
# STATUS setter (minimal in-place text edit)
# --------------------------------------------------------------------------
def set_status_in_file(
    path: Path, target_ids: set[str], new_status: str, dry_run: bool
) -> list[tuple[str, str, str]]:
    """Edit only the ``status:`` line of each targeted question in ``path``.

    Returns a list of (question_id, old_status, new_status) for changes made
    (or that would be made under --dry-run). Blank tuples are omitted; a
    question already at ``new_status`` is reported with old == new.
    """
    text = path.read_text()
    had_final_nl = text.endswith("\n")
    lines = text.splitlines()

    # Find (index, id) for every question list item in file order.
    id_hits: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        m = ID_LINE_RE.match(line)
        if m:
            id_hits.append((i, m.group(2)))

    changes: list[tuple[str, str, str]] = []
    for hit_idx, (start, qid) in enumerate(id_hits):
        if qid not in target_ids:
            continue
        end = id_hits[hit_idx + 1][0] if hit_idx + 1 < len(id_hits) else len(lines)

        # A real status FIELD sits at exactly the question's field indent.
        # Anything deeper is block-scalar text (a stem or explanation may
        # legitimately contain the words "status: ...") and must not be edited.
        id_indent = ID_LINE_RE.match(lines[start]).group(1)
        field_indent = " " * (len(id_indent) + 2)

        status_line = None
        for j in range(start, end):
            if lines[j].startswith(f"{field_indent}status:"):
                status_line = j
                break

        if status_line is not None:
            m = STATUS_LINE_RE.match(lines[status_line])
            old_status = m.group(2)
            changes.append((qid, old_status, new_status))
            if old_status != new_status:
                lines[status_line] = f"{m.group(1)}{new_status}{m.group(3)}"
        else:
            # No explicit status line (defaults to draft): insert one, aligned
            # with the question's other sub-fields.
            # Insert after the last non-blank line of the block.
            insert_at = end
            while insert_at - 1 > start and not lines[insert_at - 1].strip():
                insert_at -= 1
            lines.insert(insert_at, f"{field_indent}status: {new_status}")
            changes.append((qid, "draft", new_status))
            # Indices after the insert shift by one; refresh id_hits tail.
            for k in range(hit_idx + 1, len(id_hits)):
                id_hits[k] = (id_hits[k][0] + 1, id_hits[k][1])

    if changes and not dry_run:
        out = "\n".join(lines)
        if had_final_nl:
            out += "\n"
        path.write_text(out)

    return changes


def run_set_status(
    questions: list[dict],
    new_status: str,
    ids: set[str] | None,
    domain: str | None,
    status: str | None,
    has_file: bool,
    dry_run: bool,
) -> int:
    # Guard: never flip the entire bank by accident.
    if not (ids or domain or status is not None or has_file):
        sys.exit(
            "error: --set-status needs a selector "
            "(--ids, --file, --domain, or --status) to scope the change"
        )

    selected = apply_filters(questions, domain, status, ids)

    if ids:
        found = {q["id"] for q in selected}
        missing = sorted(ids - found)
        if missing:
            sys.exit(f"error: unknown question id(s): {', '.join(missing)}")

    if not selected:
        print("(no questions match the given selectors; nothing to do)")
        return 0

    # Group selected ids by file, then edit each file once.
    by_file: dict[Path, set[str]] = {}
    for q in selected:
        by_file.setdefault(q["file"], set()).add(q["id"])

    all_changes: list[tuple[Path, str, str, str]] = []
    for path, target_ids in by_file.items():
        for qid, old, new in set_status_in_file(
            path, target_ids, new_status, dry_run
        ):
            all_changes.append((path, qid, old, new))

    verb = "would set" if dry_run else "set"
    changed = 0
    for path, qid, old, new in sorted(all_changes, key=lambda c: (c[0].name, c[1])):
        try:
            rel = path.relative_to(REPO)
        except ValueError:
            rel = path
        if old == new:
            print(f"  {qid}: already {new} (no change)  [{rel}]")
        else:
            print(f"  {qid}: {old} -> {new}  [{rel}]")
            changed += 1

    print()
    print(f"{verb} {changed} question(s) to '{new_status}'"
          + (" (dry run: no files written)" if dry_run else ""))
    if not dry_run and changed:
        print("Verify with: git diff -- content/questions   "
              "(only status: lines should change)")
    return 0


# --------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser(
        description="Review and gate the FCLE question bank.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            """\
            modes:
              (default)            list/review matching questions as cards
              --report             per-domain coverage vs the Mock FCLE threshold
              --set-status STATUS  flip status with a minimal in-place edit

            See the module docstring / content/questions/README.md for the flow.
            """
        ),
    )
    ap.add_argument("--report", action="store_true", help="coverage report")
    ap.add_argument(
        "--set-status",
        choices=STATUSES,
        metavar="STATUS",
        help="set status of selected questions (draft|reviewed|published)",
    )
    ap.add_argument("--domain", choices=list(DOMAINS), help="filter by domain")
    ap.add_argument("--status", choices=STATUSES, help="filter by current status")
    ap.add_argument("--file", help="limit to one question YAML (path or filename)")
    ap.add_argument("--ids", help="comma-separated question ids")
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="with --set-status, preview changes without writing",
    )
    args = ap.parse_args()

    files = question_files(args.file)
    ids = (
        {s.strip() for s in args.ids.split(",") if s.strip()}
        if args.ids
        else None
    )
    objectives = load_objectives()
    questions = load_questions(files)

    if args.report and args.set_status:
        sys.exit("error: --report and --set-status are mutually exclusive")

    if args.set_status:
        run_set_status(
            questions, args.set_status, ids, args.domain, args.status,
            bool(args.file), args.dry_run
        )
        return

    if args.report:
        # A report should reflect the whole bank unless --file was given.
        print_report(questions, objectives)
        return

    # Default: LIST/REVIEW view.
    print_cards(apply_filters(questions, args.domain, args.status, ids), objectives)


if __name__ == "__main__":
    main()
