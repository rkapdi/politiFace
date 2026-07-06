#!/usr/bin/env python3
"""Enrich the congressional roster from api.congress.gov into canonical YAML.

Adds per-member legislative activity (sponsored/cosponsored counts),
leadership history, honorific, and the official portrait attribution.
Everything lands in content/people/enrichment.yaml, bundled with the app,
so enriched Atlas pages work fully offline.

Requires CONGRESS_GOV_API_KEY in the environment (never committed; the
GitHub workflow reads it from secrets). Skips gracefully when unset so
unkeyed content runs still work.

Usage:
  CONGRESS_GOV_API_KEY=... python scripts/enrich_members.py
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
from datetime import date
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
LEGISLATORS = REPO / "content" / "people" / "legislators.yaml"
OUT = REPO / "content" / "people" / "enrichment.yaml"
API = "https://api.congress.gov/v3/member/{bioguide}"
USER_AGENT = "politiface-content-pipeline (rkapdi4@gmail.com)"


def fetch_member(bioguide: str, key: str) -> dict:
    url = f"{API.format(bioguide=bioguide)}?api_key={key}&format=json"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)["member"]


def main() -> None:
    key = os.environ.get("CONGRESS_GOV_API_KEY", "").strip()
    if not key:
        print("CONGRESS_GOV_API_KEY not set; skipping enrichment.")
        return

    people = yaml.safe_load(LEGISLATORS.read_text())["people"]
    enrichment: dict[str, dict] = {}
    failures: list[str] = []

    for i, p in enumerate(people):
        bioguide = p["id"]
        try:
            m = fetch_member(bioguide, key)
        except Exception as e:  # noqa: BLE001 - one bad member must not kill the run
            failures.append(f"{bioguide}: {e}")
            continue
        leadership = [
            {"type": entry.get("type"), "congress": entry.get("congress")}
            for entry in (m.get("leadership") or [])
        ]
        enrichment[bioguide] = {
            "honorific": m.get("honorificName"),
            "sponsored_count": (m.get("sponsoredLegislation") or {}).get("count"),
            "cosponsored_count": (m.get("cosponsoredLegislation") or {}).get("count"),
            "leadership": leadership,
            "portrait_attribution": (m.get("depiction") or {}).get("attribution"),
        }
        if (i + 1) % 100 == 0:
            print(f"  {i + 1}/{len(people)} members enriched")
        time.sleep(0.15)  # stay far under the hourly rate limit

    doc = {
        "updated": date.today().isoformat(),
        "source": "api.congress.gov v3 member endpoint",
        "members": {k: enrichment[k] for k in sorted(enrichment)},
    }
    OUT.write_text(yaml.safe_dump(doc, sort_keys=False, allow_unicode=True,
                                  width=88))
    print(f"wrote enrichment for {len(enrichment)} members to {OUT}")
    if failures:
        print(f"{len(failures)} failures:", "; ".join(failures[:5]))


if __name__ == "__main__":
    sys.exit(main())
