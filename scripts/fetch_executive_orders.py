#!/usr/bin/env python3
"""Fetch executive orders from the Federal Register API into canonical YAML.

Writes content/atlas/executive_orders.yaml, the auditable source the app
bundles and the ingest loads into public.entities. Re-run to refresh; the
output is deterministic (sorted by EO number, descending) so diffs review
cleanly.

Usage:
  python scripts/fetch_executive_orders.py [--since 2025-01-20]

The Federal Register is a primary public source (the official journal of
the U.S. government); every entry carries its federalregister.gov URL as
the citation.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

import yaml

OUT = Path(__file__).resolve().parent.parent / "content" / "atlas" / "executive_orders.yaml"

API = "https://www.federalregister.gov/api/v1/documents.json"
FIELDS = [
    "executive_order_number", "title", "signing_date", "president",
    "html_url", "citation", "document_number", "abstract",
]
USER_AGENT = "politiface-content-pipeline (rkapdi4@gmail.com)"


def fetch(since: str) -> list[dict]:
    params = [
        ("conditions[type][]", "PRESDOCU"),
        ("conditions[presidential_document_type][]", "executive_order"),
        ("conditions[signing_date][gte]", since),
        ("per_page", "100"),
        ("order", "executive_order_number"),
    ] + [("fields[]", f) for f in FIELDS]
    url = f"{API}?{urllib.parse.urlencode(params)}"

    results: list[dict] = []
    while url:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as resp:
            page = json.load(resp)
        results.extend(page.get("results") or [])
        url = page.get("next_page_url")
    return results


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--since", default="2025-01-20",
                    help="earliest signing date (default: 2025-01-20)")
    args = ap.parse_args()

    raw = fetch(args.since)
    orders = []
    for r in raw:
        number = r.get("executive_order_number")
        if not number:  # notices/corrections tagged as EOs; skip
            continue
        orders.append({
            "eo_number": int(number),
            "title": (r.get("title") or "").strip(),
            "president": (r.get("president") or {}).get("name"),
            "signing_date": r.get("signing_date"),
            "federal_register_citation": r.get("citation"),
            "document_number": r.get("document_number"),
            "url": r.get("html_url"),
            "abstract": (r.get("abstract") or None),
        })

    # Deterministic output: newest first, dedupe on eo_number keeping the
    # first (the API can return amendments as separate documents).
    seen: set[int] = set()
    deduped = []
    for o in sorted(orders, key=lambda x: -x["eo_number"]):
        if o["eo_number"] in seen:
            continue
        seen.add(o["eo_number"])
        deduped.append(o)

    doc = {
        "updated": date.today().isoformat(),
        "source": "Federal Register API "
                  "(https://www.federalregister.gov/developers/documentation/api/v1)",
        "since": args.since,
        "orders": deduped,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(yaml.safe_dump(doc, sort_keys=False, allow_unicode=True,
                                  width=88))
    print(f"wrote {len(deduped)} executive orders to {OUT}")


if __name__ == "__main__":
    sys.exit(main())
