#!/usr/bin/env python3
"""Fetch the public laws of the current Congress into canonical YAML.

Source: api.congress.gov v3 law endpoint, plus one bill-detail call per
law for the sponsor (which cross-links each law to its sponsor's Atlas
person page). The 50 most recently enacted laws also get their newest
CRS summary from the /summaries endpoint (public domain, Congressional
Research Service). Output content/atlas/recent_laws.yaml, deterministic
(newest first), bundled for offline reference.

Requires CONGRESS_GOV_API_KEY in the environment.

Usage:
  CONGRESS_GOV_API_KEY=... python scripts/fetch_recent_laws.py [--congress 119]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.request
from datetime import date
from pathlib import Path

import yaml

from fetch_recent_bills import fetch_summary

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "content" / "atlas" / "recent_laws.yaml"
USER_AGENT = "politiface-content-pipeline (rkapdi4@gmail.com)"

BILL_TYPE_SLUGS = {
    "HR": "house-bill", "S": "senate-bill",
    "HJRES": "house-joint-resolution", "SJRES": "senate-joint-resolution",
}
ORDINALS = {119: "119th", 120: "120th"}


def get(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def web_url(congress: int, bill_type: str, number: str) -> str:
    slug = BILL_TYPE_SLUGS.get(bill_type.upper(), bill_type.lower())
    ordinal = ORDINALS.get(congress, f"{congress}th")
    return f"https://www.congress.gov/bill/{ordinal}-congress/{slug}/{number}"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--congress", type=int, default=119)
    args = ap.parse_args()

    key = os.environ.get("CONGRESS_GOV_API_KEY", "").strip()
    if not key:
        print("CONGRESS_GOV_API_KEY not set; skipping recent laws.")
        return

    bills: list[dict] = []
    offset = 0
    while True:
        page = get(f"https://api.congress.gov/v3/law/{args.congress}"
                   f"?api_key={key}&format=json&limit=250&offset={offset}")
        chunk = page.get("bills") or []
        bills.extend(chunk)
        offset += len(chunk)
        if offset >= page["pagination"]["count"] or not chunk:
            break

    laws = []
    for i, b in enumerate(bills):
        sponsor = None
        try:
            detail = get(f"{b['url']}&api_key={key}") \
                if "?" in b["url"] else get(f"{b['url']}?api_key={key}&format=json")
            sponsors = detail.get("bill", {}).get("sponsors") or []
            if sponsors:
                sponsor = {
                    "bioguide": sponsors[0].get("bioguideId"),
                    "name": sponsors[0].get("fullName"),
                }
        except Exception:  # noqa: BLE001 - sponsor is optional garnish
            pass
        law_numbers = [x.get("number") for x in (b.get("laws") or [])]
        laws.append({
            "law_number": law_numbers[0] if law_numbers else None,
            "title": (b.get("title") or "").strip(),
            "bill": f"{b.get('type')} {b.get('number')}",
            "enacted_date": (b.get("latestAction") or {}).get("actionDate"),
            "origin_chamber": b.get("originChamber"),
            "sponsor": sponsor,
            "url": web_url(args.congress, b.get("type") or "", b.get("number") or ""),
        })
        if (i + 1) % 25 == 0:
            print(f"  {i + 1}/{len(bills)} sponsors resolved")
        time.sleep(0.15)

    laws.sort(key=lambda x: (x["enacted_date"] or "", x["law_number"] or ""),
              reverse=True)

    # CRS summaries for the 50 most recently enacted laws only, keeping
    # the bundled file inside its budget.
    for i, law in enumerate(laws[:50]):
        parts = (law.get("bill") or "").split()
        if len(parts) != 2:
            continue
        summary = fetch_summary(key, args.congress, parts[0], parts[1])
        if summary is not None:
            law["summary"] = summary["text"]
            law["summary_version"] = summary["version"]
            law["summary_date"] = summary["date"]
            law["summary_truncated"] = summary["truncated"]
        if (i + 1) % 25 == 0:
            print(f"  {i + 1}/{min(len(laws), 50)} law summaries fetched")
        time.sleep(0.15)

    doc = {
        "updated": date.today().isoformat(),
        "source": ("api.congress.gov v3 law endpoint; summaries from the "
                   "/summaries endpoint, written by the Congressional "
                   "Research Service"),
        "congress": args.congress,
        "laws": laws,
    }
    OUT.write_text(yaml.safe_dump(doc, sort_keys=False, allow_unicode=True,
                                  width=88))
    size = OUT.stat().st_size
    if size > 256_000:
        print(f"ERROR: {OUT} is {size / 1024:.0f} KB, over the 256 KB "
              "bundle budget; lower the summary count or cap.",
              file=sys.stderr)
        sys.exit(1)
    print(f"wrote {len(laws)} public laws to {OUT} ({size / 1024:.0f} KB)")


if __name__ == "__main__":
    sys.exit(main())
