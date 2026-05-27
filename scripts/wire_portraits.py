#!/usr/bin/env python3
"""Walk every deck YAML and rewrite each card's photo_url to point at the
bundled portrait when the politician's name has a manifest entry.

Run from repo root:

    python3 scripts/wire_portraits.py

What it does:
- Loads `app/assets/portraits/manifest.json`
- Builds a name → asset-path map
- For each YAML under `app/assets/content/decks/`:
    - For each card block, finds `name:` and `photo_url:` lines
    - Sets photo_url to `assets/portraits/<file>` on match, or `null` on miss
- Preserves formatting + comments (line-based, not full YAML roundtrip).

Idempotent — run as many times as you want.

Prints a per-deck coverage report at the end.
"""
from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO_ROOT / "app/assets/portraits/manifest.json"
DECKS_DIR = REPO_ROOT / "app/assets/content/decks"

ASSET_PREFIX = "assets/portraits"


def normalize(s: str) -> str:
    """Lowercase, strip accents, collapse whitespace + punctuation."""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", " ", s).strip()
    return s


def load_manifest() -> dict[str, str]:
    """name (normalized) -> filename."""
    with MANIFEST_PATH.open() as f:
        data = json.load(f)
    out: dict[str, str] = {}
    for hit in data.get("hits", []):
        name = hit.get("name")
        filename = hit.get("file")
        if name and filename:
            out[normalize(name)] = filename
    return out


def rewrite_deck(path: Path, name_to_file: dict[str, str]) -> tuple[int, int]:
    """Returns (matched, total) card counts for the deck."""
    text = path.read_text()
    lines = text.splitlines()

    matched = 0
    total = 0

    # Walk the file looking for card blocks. A card block starts with a
    # line matching `^  - id:` and is followed (within the same block) by
    # a `name:` and (optionally) a `photo_url:` line.
    current_card_start: int | None = None
    current_name: str | None = None
    current_photo_idx: int | None = None

    def commit() -> None:
        nonlocal matched, total
        nonlocal current_card_start, current_name, current_photo_idx
        if current_card_start is None:
            return
        total += 1
        if current_name and current_photo_idx is not None:
            norm = normalize(current_name)
            file_match = name_to_file.get(norm)
            if file_match:
                matched += 1
                new_url = f'    photo_url: "{ASSET_PREFIX}/{file_match}"'
                lines[current_photo_idx] = new_url
            else:
                # No manifest entry → drop to a null URL so CardAvatar
                # falls back to initials instead of a random Picsum image.
                lines[current_photo_idx] = "    photo_url: null"
        current_card_start = None
        current_name = None
        current_photo_idx = None

    for i, line in enumerate(lines):
        if re.match(r"^  - id:", line):
            commit()
            current_card_start = i
        elif current_card_start is not None:
            m = re.match(r'^    name:\s*"(.+)"\s*$', line)
            if m:
                current_name = m.group(1)
                continue
            m = re.match(r"^    photo_url:", line)
            if m:
                current_photo_idx = i
                continue
    commit()

    new_text = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
    if new_text != text:
        path.write_text(new_text)
    return matched, total


def main() -> int:
    if not MANIFEST_PATH.exists():
        print(f"ERROR: manifest not found at {MANIFEST_PATH}", file=sys.stderr)
        return 1
    if not DECKS_DIR.is_dir():
        print(f"ERROR: decks dir not found at {DECKS_DIR}", file=sys.stderr)
        return 1

    name_to_file = load_manifest()
    print(f"Loaded {len(name_to_file)} manifest entries.\n")

    total_matched = 0
    total_cards = 0
    for path in sorted(DECKS_DIR.glob("*.yaml")):
        matched, total = rewrite_deck(path, name_to_file)
        total_matched += matched
        total_cards += total
        bar = "#" * matched + "." * (total - matched)
        print(f"  {path.name:40s}  {matched:>3d} / {total:<3d}  [{bar}]")

    print(
        f"\nTotal: {total_matched} / {total_cards} cards matched a portrait "
        f"({(total_matched / total_cards * 100):.0f}%)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
