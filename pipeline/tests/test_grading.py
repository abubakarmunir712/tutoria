"""Run (from pipeline/):  python -m unittest discover -s tests -v"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from grading import assignment_prompt, parse_grade, question_prompt  # noqa: E402


class ParseGrade(unittest.TestCase):
    def test_plain_json(self):
        r = parse_grade('{"verdict": "Correct", "feedback": "Well done."}')
        self.assertEqual(r, {"verdict": "correct", "feedback": "Well done."})

    def test_json_inside_prose_or_fences(self):
        r = parse_grade('Here you go:\n```json\n{"verdict": "partial", "feedback": "Nearly."}\n```')
        self.assertEqual(r["verdict"], "partial")

    def test_rejects_unknown_verdict(self):
        with self.assertRaises(ValueError):
            parse_grade('{"verdict": "maybe", "feedback": "?"}')

    def test_rejects_non_json(self):
        with self.assertRaises(ValueError):
            parse_grade("I think it is right")

    def test_feedback_is_capped(self):
        r = parse_grade('{"verdict": "correct", "feedback": "' + "x" * 2000 + '"}')
        self.assertEqual(len(r["feedback"]), 600)


class Prompts(unittest.TestCase):
    def test_question_prompt_carries_everything_the_marker_needs(self):
        p = question_prompt(
            question="What is 2+2?", expected_answer="4", rubric="Full credit if 4",
            student_answer="four", grade="B4", subject="Mathematics", first_try=False,
        )
        for part in ("What is 2+2?", "Reference answer: 4", "Full credit if 4", "four", "second and last"):
            self.assertIn(part, p)

    def test_assignment_prompt(self):
        p = assignment_prompt(
            task="Write", success_criteria="Clear steps", response="My work", reflection="", grade=None, subject=None,
        )
        self.assertIn("Success criteria: Clear steps", p)
        self.assertIn("(none)", p)


if __name__ == "__main__":
    unittest.main()
