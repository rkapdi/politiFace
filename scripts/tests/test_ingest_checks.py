#!/usr/bin/env python3
"""Inline-fixture checks for the answer-key hygiene rules in ingest --check.

No database, no YAML files: exercises check_answer_balance and
check_longest_option from scripts/ingest_content.py against small fixtures.

Run: .venv/bin/python scripts/tests/test_ingest_checks.py
 or: .venv/bin/python -m unittest discover -s scripts/tests
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ingest_content import (  # noqa: E402
    DOMAINS,
    LEGACY_UNBALANCED_IDS,
    Errors,
    Warnings,
    answer_share_violations,
    check_answer_balance,
    check_longest_option,
    correct_is_longest,
)


def q(qid: str, answer: str, domain: str = "us_constitution",
      lengths: dict[str, int] | None = None) -> dict:
    """A minimal question dict shaped like load_questions output."""
    lengths = lengths or {"a": 10, "b": 10, "c": 10, "d": 10}
    return {
        "id": qid,
        "domain_id": DOMAINS[domain],
        "answer": answer,
        "options": [{"key": k, "text": "x" * n} for k, n in lengths.items()],
    }


def keyed(prefix: str, letters: str, domain: str = "us_constitution") -> list[dict]:
    return [q(f"{prefix}-{i:03d}", a, domain) for i, a in enumerate(letters)]


class AnswerBalanceTest(unittest.TestCase):
    def run_check(self, questions, legacy=frozenset()):
        errors, warnings = Errors(), Warnings()
        check_answer_balance(questions, errors, warnings, legacy_ids=legacy)
        return errors.items, warnings.items

    def test_balanced_domain_passes(self):
        errs, warns = self.run_check(keyed("t", "abcdabcd"))
        self.assertEqual(errs, [])
        self.assertEqual(warns, [])

    def test_exactly_35_percent_is_allowed(self):
        # 7 of 20 = 35%: at the limit, not above it.
        letters = "a" * 7 + "b" * 5 + "c" * 4 + "d" * 4
        self.assertEqual(answer_share_violations(keyed("t", letters)), [])

    def test_over_35_percent_is_an_error(self):
        errs, warns = self.run_check(keyed("t", "aaaabcdb"))  # a = 4/8 = 50%
        self.assertEqual(len(errs), 1)
        self.assertIn("answer 'a' keys 4/8", errs[0])
        self.assertTrue(errs[0].startswith("us_constitution:"))
        self.assertEqual(warns, [])

    def test_below_min_items_is_skipped(self):
        errs, _ = self.run_check(keyed("t", "aaaaaaa"))  # 7 items, all "a"
        self.assertEqual(errs, [])

    def test_domains_are_counted_separately(self):
        qs = keyed("x", "aaaabbbb", "american_democracy") + keyed(
            "y", "abcdabcd", "landmark_impact")
        errs, _ = self.run_check(qs)
        self.assertEqual(len(errs), 2)  # a and b each 50% in american_democracy
        self.assertTrue(all(e.startswith("american_democracy:") for e in errs))

    def test_legacy_items_only_warn(self):
        legacy_qs = keyed("old", "aaaaaaaa")
        new_qs = keyed("new", "abcdabcd")
        legacy = frozenset(x["id"] for x in legacy_qs)
        errs, warns = self.run_check(legacy_qs + new_qs, legacy)
        self.assertEqual(errs, [])
        self.assertEqual(len(warns), 1)
        self.assertIn("8/8 legacy items", warns[0])

    def test_legacy_items_do_not_mask_new_imbalance(self):
        legacy_qs = keyed("old", "bcdbcdbc")
        new_qs = keyed("new", "aaaaabcd")
        legacy = frozenset(x["id"] for x in legacy_qs)
        errs, _ = self.run_check(legacy_qs + new_qs, legacy)
        self.assertEqual(len(errs), 1)
        self.assertIn("5/8 items", errs[0])

    def test_frozen_legacy_set_has_the_original_80(self):
        self.assertEqual(len(LEGACY_UNBALANCED_IDS), 80)


class LongestOptionTest(unittest.TestCase):
    def run_check(self, questions):
        warnings = Warnings()
        check_longest_option(questions, warnings)
        return warnings.items

    def test_ties_count_as_longest(self):
        self.assertTrue(correct_is_longest(
            q("t", "a", lengths={"a": 20, "b": 20, "c": 5, "d": 5})))
        self.assertFalse(correct_is_longest(
            q("t", "a", lengths={"a": 19, "b": 20, "c": 5, "d": 5})))

    def test_warns_above_35_percent(self):
        long_a = {"a": 30, "b": 10, "c": 10, "d": 10}
        qs = [q(f"l-{i}", "a", lengths=long_a) for i in range(4)]
        qs += [q(f"s-{i}", "b", lengths=long_a) for i in range(6)]  # 4/10
        warns = self.run_check(qs)
        self.assertEqual(len(warns), 1)
        self.assertIn("4/10 items", warns[0])

    def test_no_warning_at_or_below_35_percent(self):
        long_a = {"a": 30, "b": 10, "c": 10, "d": 10}
        qs = [q(f"l-{i}", "a", lengths=long_a) for i in range(7)]
        qs += [q(f"s-{i}", "b", lengths=long_a) for i in range(13)]  # 7/20
        self.assertEqual(self.run_check(qs), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
