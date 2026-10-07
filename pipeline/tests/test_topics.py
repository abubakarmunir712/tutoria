"""Run (from pipeline/):  python -m unittest discover -s tests -v"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from topics import build_topics, display_name  # noqa: E402


def rec(code, strand, substrand):
    return {"indicator_code": code, "strand": strand, "substrand": substrand}


class DisplayName(unittest.TestCase):
    def test_title_cases_capitals(self):
        self.assertEqual(display_name("ORAL LANGUAGE"), "Oral Language")
        self.assertEqual(display_name("COMPONENTS OF COMPUTERS AND COMPUTER SYSTEMS"), "Components of Computers and Computer Systems")

    def test_leaves_mixed_case_alone(self):
        self.assertEqual(display_name("Number: Fractions"), "Number: Fractions")
        self.assertEqual(display_name("Counting, Representation & Cardinality"), "Counting, Representation & Cardinality")

    def test_collapses_whitespace(self):
        self.assertEqual(display_name("  Two   spaces "), "Two spaces")


class BuildTopics(unittest.TestCase):
    def test_groups_and_counts_lessons(self):
        out = build_topics([
            rec("B5.1.1.1.1", "NUMBER", "Counting"), rec("B5.1.1.1.2", "NUMBER", "Counting"),
            rec("B5.1.3.1.1", "NUMBER", "Fractions"),
        ])
        self.assertEqual(out, [{"name": "Number", "topics": [
            {"name": "Counting", "lessons": 2}, {"name": "Fractions", "lessons": 1}]}])

    def test_orders_numerically_not_alphabetically(self):
        # strand 10 and sub-strand 10 must sort after 2, not after 1
        out = build_topics([
            rec("B5.10.1.1.1", "TENTH", "t"), rec("B5.2.1.1.1", "SECOND", "s"),
            rec("B5.2.10.1.1", "SECOND", "late"), rec("B5.2.2.1.1", "SECOND", "early"),
        ])
        self.assertEqual([s["name"] for s in out], ["Second", "Tenth"])
        self.assertEqual([t["name"] for t in out[0]["topics"]], ["s", "early", "late"])

    def test_shs_codes_use_the_same_positions(self):
        out = build_topics([
            rec("1.2.1.LI.1", "ALGEBRAIC THINKING", "Patterns"), rec("1.1.1.LI.1", "NUMBERS", "Real Numbers"),
        ])
        self.assertEqual([s["name"] for s in out], ["Numbers", "Algebraic Thinking"])

    def test_empty(self):
        self.assertEqual(build_topics([]), [])

    def test_unparseable_code_sorts_last_without_crashing(self):
        out = build_topics([rec("weird", "ODD", "x"), rec("B5.1.1.1.1", "FIRST", "y")])
        self.assertEqual([s["name"] for s in out], ["First", "Odd"])


if __name__ == "__main__":
    unittest.main()
