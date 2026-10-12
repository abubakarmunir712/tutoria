"""Run (from pipeline/):  python -m unittest discover -s tests -v"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from speech import speakable_text  # noqa: E402


class SpeakableTextTest(unittest.TestCase):
    def test_strips_citation_codes_and_markdown(self):
        self.assertEqual(speakable_text("**Good** try! See [B5.1.3.1.1] now."), "Good try! See now.")

    def test_reads_fractions_aloud(self):
        self.assertEqual(speakable_text("Add 3/4 and 2/5."), "Add 3 over 4 and 2 over 5.")

    def test_leaves_dates_alone(self):
        self.assertEqual(speakable_text("It is 1/2/2020"), "It is 1/2/2020")

    def test_drops_quoted_photo_text(self):
        self.assertEqual(
            speakable_text("> Read from your photo:\n> 1. Add 3/4\n\nWhat is the first step?"),
            "What is the first step?",
        )

    def test_long_reply_is_cut_at_a_sentence(self):
        out = speakable_text("One sentence here. " * 200)
        self.assertLessEqual(len(out), 1200)
        self.assertTrue(out.endswith("."))


if __name__ == "__main__":
    unittest.main()
