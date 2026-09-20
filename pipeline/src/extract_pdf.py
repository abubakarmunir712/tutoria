"""
Extract structured curriculum records from an official NaCCA curriculum PDF.

Layout (confirmed against MATHS-UPPER-PRIMARY-B4-B6.pdf): each content page is a
3-column table — Content Standards | Indicators and Exemplars | Subject Specific
Practices and Core Competencies — with no visible ruling lines, and a page header
("Basic 4 / Strand 1: NUMBER / Sub-strand 1: ...") that only appears when a new
strand/sub-strand starts (continuation pages repeat just the column headers).

Approach: cluster words by x0 into the 3 columns (gap-based, not table-ruling-based,
since there are no ruling lines), reconstruct each column's text in reading order,
then regex out content-standard codes (B4.1.1.1) and indicator codes (B4.1.1.1.1)
from their respective columns.

Run: python src/extract_pdf.py <input.pdf> <subject> <phase> -o <output.json>
"""

import argparse
import json
import re
import statistics
import sys
from dataclasses import dataclass, asdict, field
from pathlib import Path

import pdfplumber


# Source PDF sometimes splits a code across two words (e.g. 'B4.' + '1.1.1.5' as separate
# tokens), which column_text() rejoins with a space — so these tolerate whitespace between
# segments; the matched code is then whitespace-stripped before use.
CONTENT_STANDARD_RE = re.compile(r"^(B\d{1,2}\s*\.\s*\d+\s*\.\s*\d+\s*\.\s*\d+)\b")
INDICATOR_RE = re.compile(r"^(B\d{1,2}\s*\.\s*\d+\s*\.\s*\d+\s*\.\s*\d+\s*\.\s*\d+)\b")
STRAND_HEADER_RE = re.compile(r"(?<!-)(?<!Sub )\bStrand\s*\d+\s*[-:–—.]\s*(.+)", re.IGNORECASE)
SUBSTRAND_HEADER_RE = re.compile(r"Sub-strand\s*\d+\s*[-:–—.]\s*(.+)", re.IGNORECASE)
GRADE_HEADER_RE = re.compile(r"\bBasic\s+(\d)\b", re.IGNORECASE)


@dataclass
class CurriculumRecord:
    grade: str
    subject: str
    phase: str
    strand: str
    substrand: str
    content_standard_code: str
    content_standard_text: str
    indicator_code: str
    indicator_text: str
    exemplar: str
    images: list = field(default_factory=list)


def detect_cut_points(pages, n_columns=3, sample_stride=3):
    """
    Column boundaries, computed once from many pages (median of per-page gap
    detection) rather than per-page. Per-page detection is fragile — a page with
    unusual line-wrapping in one column can make the wrong gaps look widest, silently
    merging two real columns into one. Pooling across the whole document is robust to
    those one-off anomalies since the layout is otherwise consistent throughout.
    """
    samples = [[] for _ in range(n_columns - 1)]
    for page in pages[::sample_stride]:
        words = page.extract_words()
        xs = sorted(set(round(w["x0"]) for w in words))
        if len(xs) <= n_columns:
            continue
        gaps = sorted(
            ((xs[i + 1] - xs[i], (xs[i] + xs[i + 1]) / 2) for i in range(len(xs) - 1)),
            reverse=True,
        )
        cut_points = sorted(p for _, p in gaps[: n_columns - 1])
        if len(cut_points) == n_columns - 1:
            for i, cp in enumerate(cut_points):
                samples[i].append(cp)
    return [statistics.median(s) for s in samples if s]


def cluster_columns(words, cut_points):
    """Bucket words into columns using fixed x0 cut points."""
    columns = [[] for _ in range(len(cut_points) + 1)]
    for w in words:
        col = sum(1 for cp in cut_points if w["x0"] > cp)
        columns[col].append(w)
    return columns


def column_text(words):
    """Rebuild reading-order text from a column's words (line by line, by y)."""
    lines = {}
    for w in words:
        y = round(w["top"] / 3) * 3  # bucket lines that are a few px apart
        lines.setdefault(y, []).append(w)
    ordered = []
    for y in sorted(lines):
        line_words = sorted(lines[y], key=lambda w: w["x0"])
        ordered.append(" ".join(w["text"] for w in line_words))
    return "\n".join(ordered)


def parse_content_standards(text):
    """{code: full_text}, merging '... CONT'D' continuations into the same code."""
    standards = {}
    current_code = None
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        m = CONTENT_STANDARD_RE.match(line)
        if m:
            current_code = re.sub(r"\s+", "", m.group(1))
            standards.setdefault(current_code, "")
            line = line[m.end():].strip()
        if current_code:
            if line.upper().endswith("CONT'D") or line.upper().endswith("CONT’D"):
                continue
            standards[current_code] = (standards[current_code] + " " + line).strip()
    return standards


def parse_indicators(text):
    """[(code, indicator_text, exemplar_text), ...] in document order."""
    entries = []
    current = None
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        m = INDICATOR_RE.match(line)
        if m:
            if current:
                entries.append(current)
            code = re.sub(r"\s+", "", m.group(1))
            rest = line[m.end():].strip()
            current = [code, rest, []]
        elif current:
            if line.lower().startswith(("e.g", "eg.", "eg ")):
                current[2].append(line)
            elif current[2]:
                current[2][-1] += " " + line
            else:
                current[1] += " " + line
    if current:
        entries.append(current)
    return [(code, text.strip(), " ".join(ex).strip()) for code, text, ex in entries]


def indicator_y_positions(words):
    """[(code, y_top), ...] sorted by y, for locating which indicator an image belongs to."""
    lines = {}
    for w in words:
        y = round(w["top"] / 3) * 3
        lines.setdefault(y, []).append(w)
    positions = []
    for y in sorted(lines):
        line_words = sorted(lines[y], key=lambda w: w["x0"])
        line_text = " ".join(w["text"] for w in line_words)
        m = INDICATOR_RE.match(line_text)
        if m:
            positions.append((m.group(1), y))
    return positions


def extract_page_images(page, positions, last_indicator, image_dir: Path, page_num: int):
    """Save each image on the page, tagged with the nearest preceding indicator code."""
    saved = {}  # indicator_code -> [relative paths]
    for i, img in enumerate(page.images):
        top = img["top"]
        code = last_indicator
        for pos_code, pos_y in positions:
            if pos_y <= top:
                code = pos_code
            else:
                break
        if code is None:
            continue  # image appears before any indicator has been seen at all
        bbox = (
            max(img["x0"], 0),
            max(img["top"], 0),
            min(img["x1"], page.width),
            min(img["bottom"], page.height),
        )
        if bbox[2] <= bbox[0] or bbox[3] <= bbox[1]:
            continue
        filename = f"page{page_num}_{i}.png"
        out_path = image_dir / filename
        try:
            page.crop(bbox).to_image(resolution=150).save(out_path)
        except Exception:
            continue
        saved.setdefault(code, []).append(f"images/{filename}")
    return saved


def extract(pdf_path: str, subject: str, phase: str, start_page: int = 0, image_dir: Path | None = None):
    records = []
    grade = strand = substrand = None
    last_indicator = None
    images_by_indicator: dict[str, list] = {}

    if image_dir:
        image_dir.mkdir(parents=True, exist_ok=True)

    with pdfplumber.open(pdf_path) as pdf:
        content_pages = pdf.pages[start_page:]
        cut_points = detect_cut_points(content_pages, n_columns=3)

        for page_num, page in enumerate(content_pages, start=start_page + 1):
            page_text = page.extract_text() or ""

            g = GRADE_HEADER_RE.search(page_text)
            if g:
                grade = f"B{g.group(1)}"
            s = STRAND_HEADER_RE.search(page_text)
            if s:
                strand = s.group(1).strip()
            ss = SUBSTRAND_HEADER_RE.search(page_text)
            if ss:
                substrand = ss.group(1).strip()

            if not grade or not strand or not substrand:
                continue  # front matter / scope-and-sequence pages before content starts

            words = page.extract_words()
            columns = cluster_columns(words, cut_points)
            if len(columns) < 2:
                continue

            standards = parse_content_standards(column_text(columns[0]))
            indicators = parse_indicators(column_text(columns[1]))

            if image_dir and page.images:
                positions = indicator_y_positions(columns[1])
                page_images = extract_page_images(page, positions, last_indicator, image_dir, page_num)
                for code, paths in page_images.items():
                    images_by_indicator.setdefault(code, []).extend(paths)

            if indicators:
                last_indicator = indicators[-1][0]

            for code, ind_text, exemplar in indicators:
                content_code = ".".join(code.split(".")[:4])
                records.append(
                    CurriculumRecord(
                        grade=grade,
                        subject=subject,
                        phase=phase,
                        strand=strand,
                        substrand=substrand,
                        content_standard_code=content_code,
                        content_standard_text=standards.get(content_code, ""),
                        indicator_code=code,
                        indicator_text=ind_text,
                        exemplar=exemplar,
                    )
                )

    for record in records:
        if record.indicator_code in images_by_indicator:
            record.images = images_by_indicator[record.indicator_code]

    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf_path")
    parser.add_argument("subject")
    parser.add_argument("phase", choices=["UPPER_PRIMARY", "JHS", "SHS"])
    parser.add_argument("-o", "--output", default=None)
    parser.add_argument("--start-page", type=int, default=0)
    parser.add_argument(
        "--image-dir",
        default=None,
        help="Directory to save extracted diagrams into (paths stored in output are relative to this dir's parent). Omit to skip image extraction.",
    )
    args = parser.parse_args()

    image_dir = Path(args.image_dir) if args.image_dir else None
    records = extract(args.pdf_path, args.subject, args.phase, args.start_page, image_dir)
    output = [asdict(r) for r in records]

    n_images = sum(len(r["images"]) for r in output)
    print(f"Extracted {len(output)} records, {n_images} associated images", file=sys.stderr)

    if args.output:
        with open(args.output, "w") as f:
            json.dump(output, f, indent=2)
        print(f"Wrote {len(output)} records to {args.output}", file=sys.stderr)
    else:
        json.dump(output, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
