"""
Extract structured curriculum records from an official NaCCA SHS 1-3 curriculum PDF.

SHS uses a different scheme from Upper Primary/JHS: codes read
<year>.<strand>.<sub-strand>.<type>.<n> with type CS (content standard), LO (learning
outcome), LI (learning indicator) or AS (assessment), e.g. 2.3.1.LI.4 = SHS 2, strand 3,
sub-strand 1, learning indicator 4. Content pages are 3 columns — Content Standards |
Learning Indicators and Pedagogical Exemplars | Assessment — and the strand/sub-strand
header only appears on the Learning Outcomes page that opens each sub-strand, so strand
state is carried across the pages that follow.

Output records use the same shape as extract_pdf.py (grade = SHS1/SHS2/SHS3), so
embed_and_load.py and the retrieval service work on them unchanged. The official SHS code
has no grade prefix and is only unique within a subject, hence retrieval always filters
by subject as well.

Run: python src/extract_shs.py <input.pdf> <subject> -o <output.json>
"""

import argparse
import json
import re
import statistics
import sys
from dataclasses import asdict
from pathlib import Path

import pdfplumber

from extract_pdf import (
    CurriculumRecord,
    clean_header,
    clean_line,
    clean_text,
    lines_from_words,
    STRAND_HEADER_RE,
    SUBSTRAND_HEADER_RE,
)

CODE_RE = re.compile(r"^(\d\s*\.\s*\d+\s*\.\s*\d+\s*\.\s*(CS|LI|AS|LO)\s*\.\s*\d+)")
WORD_CODE_RE = re.compile(r"^\d\.\d+\.\d+\.(CS|LI|AS)\.\d+$")
# Running page footers/headers like "72 | ENGLISH LANGUAGE" or "ENGLISH LANGUAGE | 73".
PAGE_FOOTER_RE = re.compile(r"\b\d{1,3}\s*\|\s*[A-Z][A-Za-z &]+|[A-Z][A-Z &]{4,}\s*\|\s*\d{1,3}\b")
EXEMPLAR_MARKER_RE = re.compile(r"^(example|e\.g|exemplar|i\.\s|1\.\s)", re.IGNORECASE)


def normalize_code(raw: str) -> str:
    return re.sub(r"\s+", "", raw)


def code_kind(code: str) -> str:
    return code.split(".")[3]


def word_groups(page):
    """Some pages carry content laid out one page-width to the left (or right) of the
    visible area (x0 < 0). Split into page-width-shifted groups, in reading order, so each
    behaves like a normal page."""
    width = page.width
    buckets = {}
    for w in page.extract_words():
        k = int(w["x0"] // width)
        buckets.setdefault(k, []).append(dict(w, x0=w["x0"] - k * width, x1=w["x1"] - k * width))
    return [buckets[k] for k in sorted(buckets)]


def page_anchors(words):
    """(cs_x, li_x, as_x) from this page's code words; each None if the page lacks them."""
    xs = {"CS": [], "LI": [], "AS": []}
    for w in words:
        m = WORD_CODE_RE.match(w["text"])
        if m:
            xs[m.group(1)].append(w["x0"])
    return tuple(statistics.median(xs[k]) if xs[k] else None for k in ("CS", "LI", "AS"))


def document_anchors(pages):
    cs, li, as_ = [], [], []
    for page in pages[::2]:
        for group in word_groups(page):
            a, b, c = page_anchors(group)
            if a is not None:
                cs.append(a)
            if b is not None:
                li.append(b)
            if c is not None:
                as_.append(c)
    med = lambda v: statistics.median(v) if v else None
    return med(cs), med(li), med(as_)


def first_column_text(words):
    """Header text from the first column only: each line is cut at its first wide
    horizontal gap, so neighbouring columns' text on the same row doesn't bleed in."""
    lines = {}
    for w in words:
        lines.setdefault(round(w["top"] / 3) * 3, []).append(w)
    out = []
    for y in sorted(lines):
        ws = sorted(lines[y], key=lambda w: w["x0"])
        kept = [ws[0]]
        for prev, w in zip(ws, ws[1:]):
            if w["x0"] - prev["x1"] > 60:
                break
            kept.append(w)
        out.append(" ".join(w["text"] for w in kept))
    return "\n".join(out)


def header_y(lines):
    """y of the 'Content Standards' table-header line, or None on continuation pages."""
    for y, line in lines:
        if line.strip().startswith("Content Standards"):
            return y
    return None


def extract(pdf_path: str, subject: str):
    records: list[CurriculumRecord] = []
    standards: dict[str, str] = {}  # CS code -> text
    strand = substrand = None
    current_cs = None  # code of the content standard the following text/indicators belong to
    current_record = None
    in_exemplar = False

    with pdfplumber.open(pdf_path) as pdf:
        pages = pdf.pages
        doc_cs, doc_li, doc_as = document_anchors(pages)

        for page in pages:
            for words in word_groups(page):
                # Strand headers only count on a sub-strand's opening (Learning Outcomes)
                # section — elsewhere the same text is in the table of contents.
                group_text = " ".join(w["text"] for w in words)
                if "Learning Outcomes" in group_text and "Subject" in group_text:
                    head = first_column_text(words)
                    s = STRAND_HEADER_RE.search(head)
                    ss = SUBSTRAND_HEADER_RE.search(head)
                    if s:
                        strand = clean_header(s.group(1))
                    if ss:
                        substrand = clean_header(ss.group(1))

                if not strand or not substrand:
                    continue
                if not any(WORD_CODE_RE.match(w["text"]) and ".LI." in w["text"] for w in words):
                    continue  # no table content in this group

                cs_x, li_x, as_x = page_anchors(words)
                li_x = li_x if li_x is not None else doc_li
                as_x = as_x if as_x is not None else doc_as
                if li_x is None:
                    continue

                cs_lines = lines_from_words([w for w in words if w["x0"] < li_x - 4])
                li_lines = lines_from_words(
                    [w for w in words if w["x0"] >= li_x - 4 and (as_x is None or w["x0"] < as_x - 4)]
                )
                top = header_y(cs_lines)
                if top is not None:  # anything above the table header is the previous section's tail
                    cs_lines = [(y, t) for y, t in cs_lines if y > top]
                    li_lines = [(y, t) for y, t in li_lines if y > top]

                page_cs = []
                for y, line in cs_lines:
                    m = CODE_RE.match(line.strip())
                    if m and code_kind(normalize_code(m.group(1))) == "CS":
                        code = normalize_code(m.group(1))
                        standards.setdefault(code, "")
                        page_cs.append((y, code))
                        current_cs = code
                        line = line.strip()[m.end():]
                    if current_cs:
                        standards[current_cs] = (standards[current_cs] + " " + line.strip()).strip()

                ys = [y for y, _ in li_lines]
                diffs = [b - a for a, b in zip(ys, ys[1:]) if b - a > 0]
                gap = statistics.median(diffs) * 1.7 if diffs else 99
                prev_y = None
                for y, line in li_lines:
                    line = clean_line(line)
                    if not line or line.startswith(("Learning Indicators", "Competencies, and GESI")):
                        continue
                    m = CODE_RE.match(line)
                    if m and code_kind(normalize_code(m.group(1))) == "LI":
                        code = normalize_code(m.group(1))
                        cs_code = current_cs
                        for cy, ccode in page_cs:  # the CS block this indicator's row sits in
                            if cy <= y + 2:
                                cs_code = ccode
                        current_record = CurriculumRecord(
                            grade=f"SHS{code.split('.')[0]}",
                            subject=subject,
                            phase="SHS",
                            strand=strand,
                            substrand=substrand,
                            content_standard_code=cs_code or "",
                            content_standard_text="",
                            indicator_code=code,
                            indicator_text=line[m.end():].strip(),
                            exemplar="",
                        )
                        records.append(current_record)
                        in_exemplar = False
                    elif current_record is not None:
                        # The first line after the code is always the indicator sentence.
                        if current_record.indicator_text and not in_exemplar and (
                            EXEMPLAR_MARKER_RE.match(line) or (prev_y is not None and y - prev_y > gap)
                        ):
                            in_exemplar = True
                        if in_exemplar:
                            current_record.exemplar = (current_record.exemplar + " " + line).strip()
                        else:
                            current_record.indicator_text = (current_record.indicator_text + " " + line).strip()
                    prev_y = y

    def clean(text):
        return clean_text(PAGE_FOOTER_RE.sub(" ", text))

    for r in records:
        r.content_standard_text = clean(standards.get(r.content_standard_code, ""))
        r.indicator_text = clean(r.indicator_text)
        r.exemplar = clean(r.exemplar)

    # Same indicator can be matched twice; keep the fuller one.
    by_code: dict[tuple, CurriculumRecord] = {}
    for r in records:
        key = (r.grade, r.indicator_code)
        ex = by_code.get(key)
        if ex is None or len(r.indicator_text + r.exemplar) > len(ex.indicator_text + ex.exemplar):
            by_code[key] = r
    return list(by_code.values())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf_path")
    parser.add_argument("subject")
    parser.add_argument("-o", "--output", default=None)
    args = parser.parse_args()

    records = extract(args.pdf_path, args.subject)
    output = [asdict(r) for r in records]
    print(f"Extracted {len(output)} records", file=sys.stderr)
    if args.output:
        Path(args.output).write_text(json.dumps(output, indent=2))
        print(f"Wrote {len(output)} records to {args.output}", file=sys.stderr)
    else:
        json.dump(output, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
