#!/usr/bin/env python3
"""Inline-fixture checks for the CRS summary helpers.

No network, no API key: exercises strip_html and cap_summary from
scripts/fetch_recent_bills.py against small fixtures.

Run: python3 scripts/tests/test_fetch_summaries.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fetch_recent_bills import cap_summary, strip_html  # noqa: E402


def check(name: str, got, want) -> None:
    assert got == want, f"{name}: got {got!r}, want {want!r}"
    print(f"  ok {name}")


def main() -> None:
    # strip_html: paragraphs become blank lines, entities decode.
    check(
        "paragraphs and entities",
        strip_html("<p>One.</p><p>Two &amp; three.</p>"),
        "One.\n\nTwo & three.",
    )
    check("br becomes newline", strip_html("A<br/>B<br />C"), "A\nB\nC")
    check(
        "list items break",
        strip_html("<ul><li>First</li><li>Second</li></ul>"),
        "First\n\nSecond",
    )
    check(
        "nested markup drops, spaces collapse",
        strip_html("<p><strong>Bold</strong>   and  <em>italic</em>.</p>"),
        "Bold and italic.",
    )
    check(
        "numeric and named entities",
        strip_html("<p>It&#39;s &lt;80&gt; questions&nbsp;long.</p>"),
        "It's <80> questions long.",
    )
    check(
        "runs of breaks collapse",
        strip_html("<p>A</p><p></p><p></p><p>B</p>"),
        "A\n\nB",
    )
    check("plain text passes through", strip_html("No markup here."),
          "No markup here.")

    # cap_summary: under the limit is untouched.
    check("short text untouched", cap_summary("short", 100), ("short", False))
    exact = "x" * 100
    check("exactly at limit untouched", cap_summary(exact, 100),
          (exact, False))

    # Cuts at the last paragraph break past limit // 2.
    text = "A" * 60 + "\n\n" + "B" * 60
    check("paragraph-boundary cut", cap_summary(text, 100),
          ("A" * 60, True))

    # Paragraph break too early (before limit // 2): sentence fallback.
    text = "A" * 20 + "\n\n" + "B" * 40 + ". " + "C" * 60
    got, truncated = cap_summary(text, 100)
    check("sentence fallback", (got, truncated),
          ("A" * 20 + "\n\n" + "B" * 40 + ".", True))

    # No boundary at all: hard cut at the limit.
    check("hard cut", cap_summary("C" * 150, 100), ("C" * 100, True))

    # Default limit is 2500.
    long_text = ("D" * 400 + "\n\n") * 10  # 4020 chars
    got, truncated = cap_summary(long_text)
    assert truncated and len(got) <= 2500, "default cap not applied"
    assert got.endswith("D"), "cap left trailing whitespace"
    print("  ok default 2500 cap")

    print("all summary helper checks passed")


if __name__ == "__main__":
    main()
