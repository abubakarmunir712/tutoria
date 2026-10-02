"""
Extract structured curriculum records from an official NaCCA curriculum PDF
(Upper Primary B4-B6 and JHS B7-B9; SHS uses a different format — see extract_shs.py).

Layout: each content page is a table — Content Standards | Indicators and Exemplars |
Core Competencies (some subjects split Indicators and Exemplars into two columns) — with
no visible ruling lines, and a page header ("Strand 1: NUMBER / Sub-strand 1: ...") that
sets the current strand/sub-strand. Subjects differ in header casing, in whether grade
headers are on content pages, in code punctuation (B7.1.1.1: / B7/JHS1.1.1.1.) and in
how many columns the table has, so this does not assume any of those.

Approach: column boundaries are anchored on the page itself — the x position of the
indicator codes (left edge of the indicator column) and of the "Core Competencies"
header (right edge) — falling back to the document-wide median when a page lacks them.
Column text is rebuilt in reading order, then content-standard codes (B4.1.1.1) and
indicator codes (B4.1.1.1.1) are regexed out of their respective columns. Grade comes
from the code prefix, so no grade header is needed.

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


# Codes: B7.1.1.1 (content standard), B7.1.1.1.1 (indicator). Tolerates whitespace between
# segments (the PDFs sometimes split 'B4.' + '1.1.1.5' into two words), an optional
# '/JHS1' infix (Social Studies: B7/JHS1.1.1.1), and trailing '.'/':' punctuation.
_SEG = r"\s*\.\s*\d+"
CODE_RE = re.compile(rf"^(B\d{{1,2}}(?:/JHS\d)?{_SEG}{_SEG}{_SEG}(?:{_SEG})?)[.:]?")
WORD_INDICATOR_RE = re.compile(r"^B\d{1,2}(?:/JHS\d)?\.\d+\.\d+\.\d+\.\d+")
WORD_CODE_RE = re.compile(r"^B\d{1,2}(?:/JHS\d)?\.\d+\.\d+\.\d+[.:]?$")
STRAND_HEADER_RE = re.compile(r"(?<!-)(?<!Sub )\bStrand\s*\d+\s*[-:–—.]\s*(.+)", re.IGNORECASE)
SUBSTRAND_HEADER_RE = re.compile(r"Sub-?\s?strand\s*\d+\s*[-:–—.]\s*(.+)", re.IGNORECASE)
CORE_HEADER_WORDS = {"core", "subject", "competencies", "practices", "specific"}
EXEMPLAR_MARKER_RE = re.compile(r"^(e\.?\s?g\b|eg[. ]|exemplar|[•·▪●○]|\d+\s*[.)]\s|[ivx]+\s*[.)]\s)", re.IGNORECASE)
PRIVATE_USE_RE = re.compile("^[\ue000-\uf8ff]+\\s*")


# Grades each phase actually covers — drops the example codes (B1.2.3.4.1 …) that the
# intro sections of the PDFs use to explain the numbering scheme.
PHASE_GRADES = {
    "UPPER_PRIMARY": {"B4", "B5", "B6"},
    "JHS": {"B7", "B8", "B9"},
}


def normalize_code(raw: str) -> str:
    code = re.sub(r"\s+", "", raw)
    code = re.sub(r"/JHS\d", "", code)
    return code.rstrip(".:")


def code_segments(code: str) -> int:
    return len(code.split("."))


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


def lines_from_words(words, y_bucket=3):
    """[(y, text)] in reading order, built from words bucketed into lines by y."""
    lines = {}
    for w in words:
        y = round(w["top"] / y_bucket) * y_bucket
        lines.setdefault(y, []).append(w)
    out = []
    for y in sorted(lines):
        line_words = sorted(lines[y], key=lambda w: w["x0"])
        out.append((y, " ".join(w["text"] for w in line_words)))
    return out


FOOTER_RE = re.compile(r"©\s*NaCCA,?\s*Ministry of Education\s*\d{0,4}", re.IGNORECASE)
EXEMPLAR_LABEL_RE = re.compile(r"(^\s*Exemplars?\(?s?\)?\s*:\s*|\s*Exemplars?\(?s?\)?\s*:\s*$)", re.IGNORECASE)


def clean_text(text: str) -> str:
    text = FOOTER_RE.sub("", text)
    text = EXEMPLAR_LABEL_RE.sub("", text)
    return re.sub(r"\s+", " ", text).strip()


def clean_line(line: str) -> str:
    return PRIVATE_USE_RE.sub("", line.strip()).strip()


def is_progression_table(words, doc_indicator_x=None) -> bool:
    """Cross-grade scope tables put content-standard codes side by side in several x
    positions; real content pages keep them all in one column. Wrapped fragments of
    indicator codes (4-segment prefixes sitting in the indicator column) are ignored."""
    ind_xs = [w["x0"] for w in words if WORD_INDICATOR_RE.match(w["text"])]
    if doc_indicator_x is not None:
        ind_xs.append(doc_indicator_x)
    xs = [
        w["x0"]
        for w in words
        if WORD_CODE_RE.match(w["text"]) and not any(abs(w["x0"] - ix) < 6 for ix in ind_xs)
    ]
    return bool(xs) and max(xs) - min(xs) > 80


def page_layout(words):
    """Per-page column anchors: (indicator_x0, core_x0, exemplar_x0), each None if absent."""
    ind_xs = [w["x0"] for w in words if WORD_INDICATOR_RE.match(w["text"])]
    if not ind_xs:
        return None, None, None
    indicator_x = statistics.median(ind_xs)
    first_code_top = min(w["top"] for w in words if WORD_INDICATOR_RE.match(w["text"]))

    header = [w for w in words if w["top"] < first_code_top - 2]
    header_lines = lines_from_words(header)
    core_x = None
    candidates = [w["x0"] for w in header if w["text"].lower() in CORE_HEADER_WORDS and w["x0"] > indicator_x + 100]
    if candidates:
        core_x = min(candidates)

    exemplar_x = None
    # Separate Exemplars column iff the header reads "Indicator  Exemplars" — not
    # "Indicators AND Exemplars", which is one merged column.
    for w in header:
        if w["text"].lower().startswith("exemplar") and w["x0"] > indicator_x + 60:
            same_line = sorted((o for o in header if abs(o["top"] - w["top"]) < 4), key=lambda o: o["x0"])
            idx = same_line.index(w)
            prev = same_line[idx - 1]["text"].lower() if idx else ""
            if prev not in ("and", "&"):
                exemplar_x = w["x0"]
            break
    return indicator_x, core_x, exemplar_x


def detect_document_anchors(pages, sample_stride=2):
    inds, cores = [], []
    for page in pages[::sample_stride]:
        words = page.extract_words()
        if is_progression_table(words):
            continue
        ind, core, _ = page_layout(words)
        if ind is not None:
            inds.append(ind)
        if core is not None:
            cores.append(core)
    return (
        statistics.median(inds) if inds else None,
        statistics.median(cores) if cores else None,
    )


def split_columns(words, indicator_x, core_x, exemplar_x):
    """(content_standard_words, indicator_words, exemplar_words_or_None); competencies dropped."""
    cs, ind, ex = [], [], []
    for w in words:
        x = w["x0"]
        if x < indicator_x - 4:
            cs.append(w)
        elif core_x is not None and x >= core_x - 4:
            continue
        elif exemplar_x is not None and x >= exemplar_x - 4:
            ex.append(w)
        else:
            ind.append(w)
    return cs, ind, (ex if exemplar_x is not None else None)


def parse_content_standards(lines):
    """{code: full_text}, merging '... CONT'D' continuations into the same code."""
    standards = {}
    current_code = None
    for _, line in lines:
        line = line.strip()
        if not line:
            continue
        m = CODE_RE.match(line)
        if m and code_segments(normalize_code(m.group(1))) == 4:
            current_code = normalize_code(m.group(1))
            standards.setdefault(current_code, "")
            line = line[m.end():].strip()
        if current_code:
            if line.upper().endswith(("CONT'D", "CONT’D")):
                continue
            standards[current_code] = (standards[current_code] + " " + line).strip()
    return standards


def parse_indicators(ind_lines, ex_lines=None):
    """
    ([[code, y, indicator_text, exemplar_text], ...], orphan_exemplar_text).
    `orphan` is exemplar text that appears before the page's first indicator code
    (a continuation of the previous page's last indicator).

    With a separate exemplar column (ex_lines given), indicator-column lines are all
    indicator text and exemplar lines attach to the indicator whose y-range they fall in.
    With a merged column, the text after the code is the indicator until an exemplar
    marker (e.g., bullet, "1.") or a vertical gap, then everything is exemplar.
    """
    entries = []
    orphan = []
    ys = [y for y, _ in ind_lines]
    diffs = [b - a for a, b in zip(ys, ys[1:]) if b - a > 0]
    gap_threshold = statistics.median(diffs) * 1.7 if diffs else 99
    prev_y = None
    in_exemplar = False

    for y, line in ind_lines:
        line = clean_line(line)
        if not line:
            continue
        m = CODE_RE.match(line)
        if m and code_segments(normalize_code(m.group(1))) == 5:
            entries.append([normalize_code(m.group(1)), y, line[m.end():].strip(), ""])
            prev_y = y
            in_exemplar = False
            continue
        if not entries:
            orphan.append(line)
            prev_y = y
            continue
        cur = entries[-1]
        if ex_lines is not None:
            cur[2] = (cur[2] + " " + line).strip()
        else:
            if not in_exemplar and (
                EXEMPLAR_MARKER_RE.match(line) or (prev_y is not None and y - prev_y > gap_threshold)
            ):
                in_exemplar = True
            if in_exemplar:
                cur[3] = (cur[3] + " " + line).strip()
            else:
                cur[2] = (cur[2] + " " + line).strip()
        prev_y = y

    # Glued "…computersExemplar(s): 1. …" (Computing JHS): split on the marker.
    for e in entries:
        m = re.search(r"Exemplar\(?s?\)?\s*:", e[2], re.IGNORECASE)
        if m and not e[3]:
            e[3] = e[2][m.end():].strip()
            e[2] = e[2][:m.start()].strip()

    if ex_lines is not None:
        for y, line in ex_lines:
            line = clean_line(line)
            if not line:
                continue
            owner = None
            for e in entries:
                if e[1] <= y + 2:
                    owner = e
                else:
                    break
            if owner is None:
                orphan.append(line)
            else:
                owner[3] = (owner[3] + " " + line).strip()

    return entries, " ".join(orphan).strip()


def extract_page_images(page, positions, last_indicator, image_dir: Path, page_num: int, prefix: str = ""):
    """Save each image on the page, tagged with the nearest preceding indicator code."""
    saved = {}
    for i, img in enumerate(page.images):
        top = img["top"]
        code = last_indicator
        for pos_code, pos_y in positions:
            if pos_y <= top:
                code = pos_code
            else:
                break
        if code is None:
            continue
        bbox = (
            max(img["x0"], 0),
            max(img["top"], 0),
            min(img["x1"], page.width),
            min(img["bottom"], page.height),
        )
        if bbox[2] <= bbox[0] or bbox[3] <= bbox[1]:
            continue
        filename = f"{prefix}page{page_num}_{i}.png"
        try:
            page.crop(bbox).to_image(resolution=150).save(image_dir / filename)
        except Exception:
            continue
        saved.setdefault(code, []).append(f"images/{filename}")
    return saved


def clean_header(text: str) -> str:
    return re.sub(r"[.\s]{3,}.*$", "", text).strip()


def extract(
    pdf_path: str,
    subject: str,
    phase: str,
    start_page: int = 0,
    image_dir: Path | None = None,
    image_prefix: str = "",
):
    records: list[CurriculumRecord] = []
    strand = substrand = None
    last_indicator = None
    images_by_indicator: dict[str, list] = {}

    if image_dir:
        image_dir.mkdir(parents=True, exist_ok=True)

    with pdfplumber.open(pdf_path) as pdf:
        content_pages = pdf.pages[start_page:]
        doc_indicator_x, doc_core_x = detect_document_anchors(content_pages)

        for page_num, page in enumerate(content_pages, start=start_page + 1):
            page_text = page.extract_text() or ""
            words = page.extract_words()

            if is_progression_table(words, doc_indicator_x):
                continue

            s = STRAND_HEADER_RE.search(page_text)
            if s:
                strand = clean_header(s.group(1))
            ss = SUBSTRAND_HEADER_RE.search(page_text)
            if ss:
                substrand = clean_header(ss.group(1))

            indicator_x, core_x, exemplar_x = page_layout(words)
            if indicator_x is None:
                indicator_x = doc_indicator_x
            if core_x is None:
                core_x = doc_core_x
            if indicator_x is None or not strand or not substrand:
                continue

            cs_words, ind_words, ex_words = split_columns(words, indicator_x, core_x, exemplar_x)
            standards = parse_content_standards(lines_from_words(cs_words))
            ind_lines = lines_from_words(ind_words)
            ex_lines = lines_from_words(ex_words) if ex_words is not None else None
            indicators, orphan = parse_indicators(ind_lines, ex_lines)

            if orphan and records:
                prev = records[-1]
                prev.exemplar = (prev.exemplar + " " + orphan).strip()

            if image_dir and page.images:
                positions = [(c, y) for c, y, _, _ in indicators]
                for code, paths in extract_page_images(page, positions, last_indicator, image_dir, page_num, image_prefix).items():
                    images_by_indicator.setdefault(code, []).extend(paths)

            if indicators:
                last_indicator = indicators[-1][0]

            for code, _, ind_text, exemplar in indicators:
                if code.split(".")[0] not in PHASE_GRADES.get(phase, {code.split(".")[0]}):
                    continue
                content_code = ".".join(code.split(".")[:4])
                records.append(
                    CurriculumRecord(
                        grade=code.split(".")[0],
                        subject=subject,
                        phase=phase,
                        strand=strand,
                        substrand=substrand,
                        content_standard_code=content_code,
                        content_standard_text=clean_text(standards.get(content_code, "")),
                        indicator_code=code,
                        indicator_text=clean_text(ind_text),
                        exemplar=clean_text(exemplar),
                    )
                )

    # Same indicator can appear twice (e.g. repeated in a summary table); keep the fuller one.
    by_code: dict[str, CurriculumRecord] = {}
    for record in records:
        existing = by_code.get(record.indicator_code)
        if existing is None or len(record.indicator_text + record.exemplar) > len(existing.indicator_text + existing.exemplar):
            by_code[record.indicator_code] = record
    records = list(by_code.values())

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
    parser.add_argument(
        "--image-prefix",
        default="",
        help="Prefix for saved image filenames, so images from different PDFs sharing one directory don't collide (e.g. 'maths-b4-b6-').",
    )
    args = parser.parse_args()

    image_dir = Path(args.image_dir) if args.image_dir else None
    records = extract(args.pdf_path, args.subject, args.phase, args.start_page, image_dir, args.image_prefix)
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
