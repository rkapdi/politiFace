#!/usr/bin/env python3
"""Fetch recently-acted-on bills into canonical YAML for the civic feed.

Source: api.congress.gov v3 bill endpoint sorted by update date. Each
entry carries the bill, its latest action (the "motion" line: passed
committee, passed a chamber, presented to the President, and so on), and
the congress.gov link. Each bill also gets its newest CRS summary from
the /summaries endpoint (public domain, written by the Congressional
Research Service), stripped to plain text and capped for the offline
bundle. Bundled for offline; refreshed by the weekly workflow, so the
feed is as fresh as the last content merge.

Requires CONGRESS_GOV_API_KEY in the environment.

Usage:
  CONGRESS_GOV_API_KEY=... python scripts/fetch_recent_bills.py \
      [--limit 150] [--no-summaries]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from datetime import date
from html.parser import HTMLParser
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


class _TextExtractor(HTMLParser):
    """Collects character data; paragraph-ish end tags become breaks."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs) -> None:  # noqa: ANN001
        if tag == "br":
            self.parts.append("\n")

    def handle_startendtag(self, tag: str, attrs) -> None:  # noqa: ANN001
        if tag == "br":
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in ("p", "li", "ul", "ol"):
            self.parts.append("\n\n")

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def strip_html(html_text: str) -> str:
    """CRS summary HTML to plain text with paragraph breaks preserved."""
    parser = _TextExtractor()
    parser.feed(html_text)
    parser.close()
    text = "".join(parser.parts).replace("\xa0", " ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" ?\n ?", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def cap_summary(text: str, limit: int = 2500) -> tuple[str, bool]:
    """Cap at a paragraph break (fallback: sentence) before `limit`."""
    if len(text) <= limit:
        return text, False
    cut = text.rfind("\n\n", 0, limit)
    if cut <= limit // 2:
        cut = text.rfind(". ", 0, limit)
        cut = limit if cut == -1 else cut + 1
    return text[:cut].rstrip(), True


def fetch_summary(key: str, congress: int, bill_type: str,
                  number: str) -> dict | None:
    """Newest CRS summary for one bill, stripped and capped.

    Per-bill failures must not fail the run: any error returns None.
    """
    try:
        url = (f"https://api.congress.gov/v3/bill/{congress}/"
               f"{bill_type.lower()}/{number}/summaries"
               f"?api_key={key}&format=json")
        docs = get(url).get("summaries") or []
        if not docs:
            return None
        entry = max(
            docs,
            key=lambda d: d.get("updateDate") or d.get("actionDate") or "",
        )
        text, truncated = cap_summary(strip_html(entry.get("text") or ""))
        if not text:
            return None
        return {
            "text": text,
            "version": entry.get("actionDesc"),
            "date": entry.get("actionDate"),
            "truncated": truncated,
        }
    except Exception:  # noqa: BLE001 - one 404 must not kill the content PR
        return None


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--limit", type=int, default=150)
    ap.add_argument("--no-summaries", action="store_false", dest="summaries",
                    default=True,
                    help="skip the per-bill CRS summary calls")
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
    for i, b in enumerate(bills[: args.limit]):
        action = b.get("latestAction") or {}
        entry = {
            "bill": f"{b.get('type')} {b.get('number')}",
            "congress": b.get("congress"),
            "title": (b.get("title") or "").strip(),
            "action_date": action.get("actionDate"),
            "action": (action.get("text") or "").strip(),
            "origin_chamber": b.get("originChamber"),
            "url": web_url(b.get("congress") or 0, b.get("type") or "",
                           str(b.get("number") or "")),
        }
        if args.summaries:
            summary = fetch_summary(key, b.get("congress") or 0,
                                    b.get("type") or "",
                                    str(b.get("number") or ""))
            if summary is not None:
                entry["summary"] = summary["text"]
                entry["summary_version"] = summary["version"]
                entry["summary_date"] = summary["date"]
                entry["summary_truncated"] = summary["truncated"]
            time.sleep(0.15)
        entries.append(entry)
        if (i + 1) % 25 == 0:
            print(f"  {i + 1}/{min(len(bills), args.limit)} bills processed")

    entries.sort(key=lambda x: (x["action_date"] or "", x["bill"]),
                 reverse=True)
    doc = {
        "updated": date.today().isoformat(),
        "source": ("api.congress.gov v3 bill endpoint (sorted by update "
                   "date); summaries from the /summaries endpoint, written "
                   "by the Congressional Research Service"),
        "bills": entries,
    }
    OUT.write_text(yaml.safe_dump(doc, sort_keys=False, allow_unicode=True,
                                  width=88))
    size = OUT.stat().st_size
    if size > 512_000:
        print(f"ERROR: {OUT} is {size / 1024:.0f} KB, over the 512 KB "
              "bundle budget; lower --limit or the summary cap.",
              file=sys.stderr)
        sys.exit(1)
    print(f"wrote {len(entries)} recent bill actions to {OUT} "
          f"({size / 1024:.0f} KB)")


if __name__ == "__main__":
    sys.exit(main())
