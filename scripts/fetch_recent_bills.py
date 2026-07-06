#!/usr/bin/env python3
"""Fetch recently-acted-on bills into canonical YAML for the civic feed.

Source: api.congress.gov v3 bill endpoint sorted by update date. Each
entry carries the bill, its latest action (the "motion" line: passed
committee, passed a chamber, presented to the President, and so on), and
the congress.gov link. Bundled for offline; refreshed by the weekly
workflow, so the feed is as fresh as the last content merge.

Requires CONGRESS_GOV_API_KEY in the environment.

Usage:
  CONGRESS_GOV_API_KEY=... python scripts/fetch_recent_bills.py [--limit 150]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request
from datetime import date
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "content" / "atlas" / "recent_bills.yaml"
USER_AGENT = "politiface-content-pipeline (rkapdi4@gmail.com)"

BILL_TYPE_SLUGS = {
    "HR": "house-bill", "S": "senate-bill",
    "HJRES": "house-joint-resolution", "SJRES": "senate-joint-resolution",
    "HCONRES": "house-concurrent-resolution",
    "SCONRES": "senate-concurrent-resolution",
    "HRES": "house-resolution", "SRES": "senate-resolution",
}


def get(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def web_url(congress: int, bill_type: str, number: str) -> str:
    slug = BILL_TYPE_SLUGS.get(bill_type.upper(), bill_type.lower())
    return (f"https://www.congress.gov/bill/{congress}th-congress/"
            f"{slug}/{number}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--limit", type=int, default=150)
    args = ap.parse_args()

    key = os.environ.get("CONGRESS_GOV_API_KEY", "").strip()
    if not key:
        print("CONGRESS_GOV_API_KEY not set; skipping recent bills.")
        return

    bills: list[dict] = []
    offset = 0
    while len(bills) < args.limit:
        page = get(f"https://api.congress.gov/v3/bill?api_key={key}"
                   f"&format=json&sort=updateDate+desc&limit=250"
                   f"&offset={offset}")
        chunk = page.get("bills") or []
        if not chunk:
            break
        bills.extend(chunk)
        offset += len(chunk)

    entries = []
    for b in bills[: args.limit]:
        action = b.get("latestAction") or {}
        entries.append({
            "bill": f"{b.get('type')} {b.get('number')}",
            "congress": b.get("congress"),
            "title": (b.get("title") or "").strip(),
            "action_date": action.get("actionDate"),
            "action": (action.get("text") or "").strip(),
            "origin_chamber": b.get("originChamber"),
            "url": web_url(b.get("congress") or 0, b.get("type") or "",
                           str(b.get("number") or "")),
        })

    entries.sort(key=lambda x: (x["action_date"] or "", x["bill"]),
                 reverse=True)
    doc = {
        "updated": date.today().isoformat(),
        "source": "api.congress.gov v3 bill endpoint (sorted by update date)",
        "bills": entries,
    }
    OUT.write_text(yaml.safe_dump(doc, sort_keys=False, allow_unicode=True,
                                  width=88))
    print(f"wrote {len(entries)} recent bill actions to {OUT}")


if __name__ == "__main__":
    sys.exit(main())
