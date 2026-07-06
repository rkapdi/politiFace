#!/usr/bin/env python3
"""Fetch and recompress congressional portraits for bundling.

Source: unitedstates/images (official congressional photos). Downloads the
225x275 rendition for every member in content/people/legislators.yaml and
recompresses to a bundle-friendly JPEG (~10-15KB) under
app/assets/content/portraits/congress/<bioguide>.jpg. Members without a
photo fall back to initials in the app (CardAvatar behavior).

Writes a manifest with the attribution line. Requires Pillow.

Usage:
  python scripts/fetch_member_photos.py [--quality 58] [--only-missing]
"""

from __future__ import annotations

import argparse
import io
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

import yaml
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
LEGISLATORS = REPO / "content" / "people" / "legislators.yaml"
OUT_DIR = REPO / "app" / "assets" / "content" / "portraits" / "congress"
IMG_URL = "https://unitedstates.github.io/images/congress/225x275/{bioguide}.jpg"
USER_AGENT = "politiface-content-pipeline (rkapdi4@gmail.com)"


def fetch(bioguide: str) -> bytes | None:
    req = urllib.request.Request(
        IMG_URL.format(bioguide=bioguide),
        headers={"User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def recompress(data: bytes, quality: int) -> bytes:
    img = Image.open(io.BytesIO(data)).convert("RGB")
    # 180x220 is plenty for list avatars and reads fine on the detail
    # header at 3x; hi-res stays a tap away at the official source.
    img.thumbnail((180, 220))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=quality, optimize=True, progressive=True)
    return buf.getvalue()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--quality", type=int, default=58)
    ap.add_argument("--only-missing", action="store_true",
                    help="skip members whose thumbnail already exists")
    args = ap.parse_args()

    doc = yaml.safe_load(LEGISLATORS.read_text())
    people = doc["people"]
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    ok, missing, skipped, total_bytes = 0, [], 0, 0
    for p in people:
        bioguide = p["id"]
        target = OUT_DIR / f"{bioguide}.jpg"
        if args.only_missing and target.exists():
            skipped += 1
            total_bytes += target.stat().st_size
            continue
        raw = fetch(bioguide)
        if raw is None:
            missing.append(bioguide)
            continue
        out = recompress(raw, args.quality)
        target.write_bytes(out)
        ok += 1
        total_bytes += len(out)

    manifest = {
        "source": "unitedstates/images (official congressional photos)",
        "rendition": "180x220 JPEG derived from the 225x275 originals",
        "count": ok + skipped,
        "missing": sorted(missing),
    }
    (OUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(f"portraits: {ok} fetched, {skipped} kept, {len(missing)} missing, "
          f"total {total_bytes / 1024 / 1024:.1f} MB")
    if missing:
        print("no photo (app shows initials):", ", ".join(sorted(missing)))


if __name__ == "__main__":
    sys.exit(main())
