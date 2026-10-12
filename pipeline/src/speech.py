"""Helpers for the voice path: what a tutor reply should sound like when read aloud."""

import re

CITATION_RE = re.compile(r"\s*\[(?:B[4-9]|SHS[123])\.[\d.]+\]")
FRACTION_RE = re.compile(r"(?<![\d./])(\d+)\s*/\s*(\d+)(?![\d/])")
MARKDOWN_RE = re.compile(r"[*_`#>]+")
QUOTE_BLOCK_RE = re.compile(r"^\s*>.*$", re.MULTILINE)
MAX_SPOKEN_CHARS = 1200


def speakable_text(answer: str) -> str:
    """Drop what is only meant for the eye (indicator-code chips, markdown, the quoted photo
    text) and spell out fractions so they are read as "3 over 4", not as a date."""
    text = QUOTE_BLOCK_RE.sub("", answer)
    text = CITATION_RE.sub("", text)
    text = FRACTION_RE.sub(r"\1 over \2", text)
    text = MARKDOWN_RE.sub("", text)
    text = re.sub(r"\s*\n\s*", " ", text)
    text = re.sub(r"\s{2,}", " ", text).strip()
    if len(text) > MAX_SPOKEN_CHARS:
        cut = text[:MAX_SPOKEN_CHARS]
        text = cut[: cut.rfind(". ") + 1] or cut
    return text
