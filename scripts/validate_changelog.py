#!/usr/bin/env python3
"""Validate docs/_data/changelog.yml, the source of the /changelog page.

Checks entry shape, newest-first order, unique ids and builds, house style
(no em-dashes), and that the build in app/pubspec.yaml has an entry, so a
version bump cannot merge without one.

Run: python3 scripts/validate_changelog.py
"""

from __future__ import annotations

import datetime as dt
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "docs/_data/changelog.yml"
PUBSPEC = ROOT / "app/pubspec.yaml"

PLATFORMS = {"iOS", "Web", "Website", "Content"}
REQUIRED = {"id", "date", "platform", "title", "items"}
ALLOWED = REQUIRED | {"version", "build", "channel", "link"}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")


def validate(entries: object, pubspec_build: int | None) -> list[str]:
    """Returns one message per problem; empty means valid."""
    if not isinstance(entries, list) or not entries:
        return ["changelog must be a non-empty list of entries"]

    errors: list[str] = []
    seen_ids: set[str] = set()
    seen_builds: set[int] = set()
    previous: dt.date | None = None

    for index, entry in enumerate(entries):
        where = f"entry {index}"
        if not isinstance(entry, dict):
            errors.append(f"{where}: must be a mapping")
            continue
        where = f"entry {entry.get('id', index)}"

        for key in sorted(REQUIRED - entry.keys()):
            errors.append(f"{where}: missing {key}")
        for key in sorted(entry.keys() - ALLOWED):
            errors.append(f"{where}: unknown field {key}")

        entry_id = entry.get("id")
        if not (isinstance(entry_id, str) and ID_RE.match(entry_id)):
            errors.append(f"{where}: id must be a lowercase slug")
        elif entry_id in seen_ids:
            errors.append(f"{where}: duplicate id")
        else:
            seen_ids.add(entry_id)

        date = entry.get("date")
        if not isinstance(date, dt.date):
            errors.append(f"{where}: date must be YYYY-MM-DD")
        else:
            if previous is not None and date > previous:
                errors.append(f"{where}: out of order, newest entries go first")
            previous = date

        platform = entry.get("platform")
        if platform not in PLATFORMS:
            errors.append(f"{where}: platform must be one of {sorted(PLATFORMS)}")
        elif platform == "iOS":
            if not isinstance(entry.get("version"), str):
                errors.append(f"{where}: iOS entries need a version")
        elif "version" in entry or "build" in entry:
            errors.append(f"{where}: only iOS entries have a version or build")

        build = entry.get("build")
        if build is not None:
            if not isinstance(build, int):
                errors.append(f"{where}: build must be a number")
            elif build in seen_builds:
                errors.append(f"{where}: duplicate build {build}")
            else:
                seen_builds.add(build)

        title = entry.get("title")
        if not (isinstance(title, str) and title.strip()):
            errors.append(f"{where}: title must be text")

        items = entry.get("items")
        if not (isinstance(items, list) and items):
            errors.append(f"{where}: items must be a non-empty list")
            items = []
        for item in items:
            if not (isinstance(item, str) and item.rstrip().endswith(".")):
                errors.append(f"{where}: item must be a sentence ending in a period: {item!r}")

        link = entry.get("link")
        if link is not None and not (isinstance(link, str) and link.startswith("https://")):
            errors.append(f"{where}: link must be https")

        text = [title, entry.get("channel"), *items]
        if any(isinstance(t, str) and "—" in t for t in text):
            errors.append(f"{where}: em-dash (house style)")

    if pubspec_build is not None and pubspec_build not in seen_builds:
        errors.append(f"app/pubspec.yaml is at build {pubspec_build}, which has no changelog entry")

    return errors


def read_pubspec_build(text: str) -> int | None:
    match = re.search(r"^version:\s*[\w.]+\+(\d+)\s*$", text, re.MULTILINE)
    return int(match.group(1)) if match else None


def main() -> int:
    entries = yaml.safe_load(CHANGELOG.read_text(encoding="utf-8"))
    errors = validate(entries, read_pubspec_build(PUBSPEC.read_text(encoding="utf-8")))
    for error in errors:
        print(f"::error file=docs/_data/changelog.yml::{error}")
    if errors:
        return 1
    print(f"changelog ok: {len(entries)} entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
