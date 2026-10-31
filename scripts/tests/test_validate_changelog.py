#!/usr/bin/env python3
"""Inline-fixture checks for scripts/validate_changelog.py.

Run: python3 scripts/tests/test_validate_changelog.py
"""

from __future__ import annotations

import datetime as dt
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from validate_changelog import read_pubspec_build, validate  # noqa: E402


def entry(**overrides: object) -> dict:
    base = {
        "id": "ios-2",
        "date": dt.date(2026, 10, 2),
        "platform": "iOS",
        "version": "1.0.0",
        "build": 2,
        "title": "A title",
        "items": ["A sentence."],
    }
    base.update(overrides)
    return base


def has(errors: list[str], fragment: str) -> bool:
    return any(fragment in error for error in errors)


def main() -> int:
    older = entry(id="ios-1", build=1, date=dt.date(2026, 10, 1))
    cases = [
        ("valid", validate([entry(), older], 2) == []),
        ("empty list", has(validate([], None), "non-empty")),
        ("missing title", has(validate([{k: v for k, v in entry().items() if k != "title"}], None), "missing title")),
        ("unknown field", has(validate([entry(extra=1)], None), "unknown field")),
        ("bad id", has(validate([entry(id="Bad Id")], None), "slug")),
        ("duplicate id", has(validate([entry(), entry(build=3)], None), "duplicate id")),
        ("duplicate build", has(validate([entry(), entry(id="other")], None), "duplicate build")),
        ("out of order", has(validate([older, entry()], None), "out of order")),
        ("same day allowed", validate([entry(), entry(id="ios-3", build=3)], None) == []),
        ("bad platform", has(validate([entry(platform="Android")], None), "platform")),
        ("ios needs version", has(validate([{k: v for k, v in entry().items() if k != "version"}], None), "need a version")),
        ("web has no build", has(validate([entry(platform="Web")], None), "only iOS")),
        ("no period", has(validate([entry(items=["No period"])], None), "ending in a period")),
        ("em-dash", has(validate([entry(items=["A — b."])], None), "em-dash")),
        ("http link", has(validate([entry(link="http://x")], None), "https")),
        ("build without entry", has(validate([entry()], 3), "build 3")),
        ("pubspec parse", read_pubspec_build("name: x\nversion: 1.3.2+34\n") == 34),
        ("pubspec no build", read_pubspec_build("version: 1.3.2\n") is None),
    ]
    failed = [name for name, ok in cases if not ok]
    for name in failed:
        print(f"FAIL: {name}")
    print(f"{len(cases) - len(failed)}/{len(cases)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
