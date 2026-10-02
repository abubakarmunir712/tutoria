"""
Manifest of the official NaCCA curriculum PDFs to index: 5 subjects x 3 phases.

`subject` / `phase` values must match the Subject rows seeded by the server
(server/prisma/seed.ts), since the app passes those names as retrieval filters.
`extractor` picks the parser: B4-B9 PDFs share one table layout (extract_pdf.py); SHS
uses a different code scheme and layout (extract_shs.py).
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Source:
    pdf: str  # filename under data/raw/
    subject: str
    phase: str  # UPPER_PRIMARY | JHS | SHS
    extractor: str  # 'basic' | 'shs'

    @property
    def slug(self) -> str:
        return f"{self.subject.lower().replace(' ', '-')}-{self.phase.lower().replace('_', '-')}"


SOURCES = [
    Source("mathematics-upper-primary-b4-b6.pdf", "Mathematics", "UPPER_PRIMARY", "basic"),
    Source("english-upper-primary-b4-b6.pdf", "English Language", "UPPER_PRIMARY", "basic"),
    Source("science-upper-primary-b4-b6.pdf", "Science", "UPPER_PRIMARY", "basic"),
    Source("our-world-our-people-upper-primary-b4-b6.pdf", "Our World and Our People", "UPPER_PRIMARY", "basic"),
    Source("computing-upper-primary-b4-b6.pdf", "Computing", "UPPER_PRIMARY", "basic"),
    Source("mathematics-jhs-b7-b9.pdf", "Mathematics", "JHS", "basic"),
    Source("english-jhs-b7-b9.pdf", "English Language", "JHS", "basic"),
    Source("science-jhs-b7-b9.pdf", "Science", "JHS", "basic"),
    Source("social-studies-jhs-b7-b9.pdf", "Social Studies", "JHS", "basic"),
    Source("computing-jhs-b7-b9.pdf", "Computing", "JHS", "basic"),
    Source("mathematics-shs.pdf", "Mathematics", "SHS", "shs"),
    Source("english-shs.pdf", "English Language", "SHS", "shs"),
    Source("science-shs.pdf", "Science", "SHS", "shs"),  # NaCCA "General Science"
    Source("social-studies-shs.pdf", "Social Studies", "SHS", "shs"),
    Source("computing-shs.pdf", "Computing", "SHS", "shs"),
]
