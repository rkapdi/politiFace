#!/usr/bin/env python3
"""Walk every deck YAML and rewrite each card's photo_url + gender to match
the bundled portrait manifest.

Run from repo root:

    python3 scripts/wire_portraits.py

What it does:
- Loads `app/assets/portraits/manifest.json`
- Builds a name → (file, gender) map
- For each YAML under `app/assets/content/decks/`:
    - For each card block, finds `name:`, `photo_url:`, and `gender:` lines
    - Sets photo_url to `assets/portraits/<file>` on match, or `null` on miss
    - Sets gender from the manifest if the card has no manual `gender:` line.
      If a card already has `gender:` set in the YAML, it is preserved —
      manual annotations beat Wikidata.
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


def load_manifest() -> dict[str, dict]:
    """name (normalized) -> {file, gender}."""
    with MANIFEST_PATH.open() as f:
        data = json.load(f)
    out: dict[str, dict] = {}
    for hit in data.get("hits", []):
        name = hit.get("name")
        filename = hit.get("file")
        if name and filename:
            out[normalize(name)] = {
                "file": filename,
                "gender": hit.get("gender"),
            }
    return out


def rewrite_deck(path: Path, name_to_meta: dict[str, dict]) -> tuple[int, int]:
    """Returns (matched, total) card counts for the deck."""
    text = path.read_text()
    src_lines = text.splitlines()

    matched = 0
    total = 0

    # Parse into card blocks. Each card starts at `^  - id:`. Within the
    # block we look for `name:`, `photo_url:`, and `gender:` lines. After
    # collecting, we emit the rewritten YAML — this single-pass build avoids
    # the index-drift mess of mutating + inserting in place.
    out_lines: list[str] = []

    name: str | None = None
    photo_idx_in_block: int | None = None
    gender_idx_in_block: int | None = None
    block_lines: list[str] = []
    in_card = False

    def flush_block() -> None:
        nonlocal matched, total
        nonlocal name, photo_idx_in_block, gender_idx_in_block, block_lines
        if not block_lines:
            return
        total += 1
        meta = name_to_meta.get(normalize(name or "")) if name else None

        # Photo URL rewrite — match → assets path, no match → null.
        if photo_idx_in_block is not None:
            if meta:
                matched += 1
                block_lines[photo_idx_in_block] = (
                    f'    photo_url: "{ASSET_PREFIX}/{meta["file"]}"'
                )
            else:
                block_lines[photo_idx_in_block] = "    photo_url: null"

        # Gender wiring — only when manifest has a value AND the YAML doesn't
        # already declare one (manual override always wins).
        if meta and meta.get("gender") and gender_idx_in_block is None:
            insert_after = (
                photo_idx_in_block
                if photo_idx_in_block is not None
                else len(block_lines) - 1
            )
            block_lines.insert(
                insert_after + 1,
                f'    gender: {meta["gender"]}',
            )

        out_lines.extend(block_lines)
        # Reset block state.
        name = None
        photo_idx_in_block = None
        gender_idx_in_block = None
        block_lines = []

    for line in src_lines:
        if re.match(r"^  - id:", line):
            if in_card:
                flush_block()
            in_card = True
            block_lines.append(line)
            continue
        if in_card:
            block_lines.append(line)
            # Lines that end the card block: another top-level key. Cards
            # are 2-space indented, so a 0-2 space line at column 0 ends them.
            if re.match(r"^[^ ]", line):
                # New top-level key encountered → end the cards section.
                flush_block()
                in_card = False
                continue
            in_block_idx = len(block_lines) - 1
            m = re.match(r'^    name:\s*"(.+)"\s*$', line)
            if m:
                name = m.group(1)
                continue
            if re.match(r"^    photo_url:", line):
                photo_idx_in_block = in_block_idx
                continue
            if re.match(r"^    gender:", line):
                gender_idx_in_block = in_block_idx
                continue
        else:
            out_lines.append(line)
    if in_card:
        flush_block()

    new_text = "\n".join(out_lines) + ("\n" if text.endswith("\n") else "")
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

    name_to_meta = load_manifest()
    with_gender = sum(1 for m in name_to_meta.values() if m.get("gender"))
    print(
        f"Loaded {len(name_to_meta)} manifest entries "
        f"({with_gender} with gender).\n"
    )

    total_matched = 0
    total_cards = 0
    for path in sorted(DECKS_DIR.glob("*.yaml")):
        matched, total = rewrite_deck(path, name_to_meta)
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
