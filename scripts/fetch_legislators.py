#!/usr/bin/env python3
"""Fetch current members of Congress into canonical YAML.

Source: the unitedstates/congress-legislators dataset (public domain,
community-maintained, the de facto canonical machine-readable roster).
Writes content/people/legislators.yaml with structured facts, the FULL
term history per member, and top-level committee assignments. Output is
deterministic (sorted by bioguide id) so refresh diffs review cleanly.

Usage:
  python scripts/fetch_legislators.py

Optional enrichment via api.congress.gov runs only when
CONGRESS_GOV_API_KEY is set in the environment (never committed).
"""

from __future__ import annotations

import json
import sys
import urllib.request
from datetime import date
from pathlib import Path

import yaml

BASE = "https://unitedstates.github.io/congress-legislators"
OUT = Path(__file__).resolve().parent.parent / "content" / "people" / "legislators.yaml"
USER_AGENT = "politiface-content-pipeline (rkapdi4@gmail.com)"

PARTY_NAMES = {
    "Democrat": "Democrat",
    "Republican": "Republican",
    "Independent": "Independent",
}


def get_yaml(name: str):
    req = urllib.request.Request(f"{BASE}/{name}", headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return yaml.safe_load(resp.read())


def main() -> None:
    legislators = get_yaml("legislators-current.yaml")
    committees = get_yaml("committees-current.yaml")
    membership = get_yaml("committee-membership-current.yaml")

    committee_names = {
        c["thomas_id"]: c["name"] for c in committees if c.get("thomas_id")
    }

    # bioguide -> [{code, name, rank, title}]
    assignments: dict[str, list[dict]] = {}
    for code, members in membership.items():
        if len(code) > 4:
            continue  # subcommittees: too granular for the reference layer
        name = committee_names.get(code)
        if not name:
            continue
        for m in members:
            bid = m.get("bioguide")
            if not bid:
                continue
            assignments.setdefault(bid, []).append({
                "code": code,
                "name": name,
                "rank": m.get("rank"),
                "title": m.get("title"),
            })

    people = []
    for leg in legislators:
        bioguide = leg["id"]["bioguide"]
        terms = leg["terms"]
        current = terms[-1]
        chamber = "senate" if current["type"] == "sen" else "house"
        person_committees = sorted(
            assignments.get(bioguide, []),
            key=lambda a: (a["title"] is None, a["rank"] or 999),
        )
        people.append({
            "id": bioguide,
            "name": leg["name"].get("official_full")
                    or f'{leg["name"]["first"]} {leg["name"]["last"]}',
            "first": leg["name"]["first"],
            "last": leg["name"]["last"],
            "birthday": leg.get("bio", {}).get("birthday"),
            "wikidata": leg["id"].get("wikidata"),
            "chamber": chamber,
            "state": current["state"],
            "district": current.get("district"),
            "party": current.get("party"),
            "current_term": {
                "start": current.get("start"),
                "end": current.get("end"),
                "url": current.get("url"),
            },
            "terms": [
                {
                    "type": t["type"],
                    "start": t.get("start"),
                    "end": t.get("end"),
                    "state": t.get("state"),
                    "district": t.get("district"),
                    "party": t.get("party"),
                }
                for t in terms
            ],
            "committees": person_committees,
            "citations": [
                f"https://bioguide.congress.gov/search/bio/{bioguide}",
            ],
        })

    people.sort(key=lambda p: p["id"])

    doc = {
        "updated": date.today().isoformat(),
        "source": "unitedstates/congress-legislators (public domain); "
                  "committee names from committees-current.yaml",
        "people": people,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(yaml.safe_dump(doc, sort_keys=False, allow_unicode=True,
                                  width=88))
    senators = sum(1 for p in people if p["chamber"] == "senate")
    print(f"wrote {len(people)} members ({senators} senators, "
          f"{len(people) - senators} representatives) to {OUT}")


if __name__ == "__main__":
    sys.exit(main())
