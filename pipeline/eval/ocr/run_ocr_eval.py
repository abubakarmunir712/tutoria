"""
Evaluate the homework-photo path: photo -> transcription -> curriculum search.

Scores, per image with ground truth (worksheets/manifest.json):
  lines    - how many expected lines were transcribed (fuzzy, ignoring case/spacing/punctuation)
  math     - every number and operator in the expected text survived exactly (the thing that
             matters most: "3/4 + 2/5" read as "3/4 + 2/6" would tutor the wrong problem)
  working  - handwritten working was recognised as the student's working, not as a question
  refused  - blank / unreadable / not-a-document images return UNREADABLE instead of an
             invented question
  topic    - the curriculum search (same query steps as the service) returns a record on the
             expected topic in its top 3

Real photos: drop .jpg/.png files into eval/ocr/real/ (git-ignored — they may show a child's
name or work). An optional <name>.json next to a photo, e.g.
  {"grade": "B5", "subject": "Mathematics", "expected_lines": ["1. Add 3/4 + 2/5"], "expect_topic": "fraction"}
turns on the same scoring; without it you just get the transcription and retrieved records to
judge by eye.

Run (from pipeline/):  python eval/ocr/run_ocr_eval.py [--real] [--only NAME ...] [-v]
Needs GEMINI_API_KEY and the Qdrant settings in the repo-root .env (it calls the real APIs).
"""

import argparse
import difflib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "src"))

from dotenv import load_dotenv  # noqa: E402

load_dotenv(HERE.parents[2] / ".env")

from llm import get_llm_provider  # noqa: E402
from retrieval import (  # noqa: E402
    build_retrieval_query,
    correct_spelling,
    curriculum_vocabulary,
    expand_student_terms,
    retrieve,
)
from service import photo_search_text, strip_student_working  # noqa: E402

WORKING_LABEL_RE = re.compile(r"student'?s working\s*:?", re.IGNORECASE)


def norm(text: str) -> str:
    return re.sub(r"[^a-z0-9/+\-=^x÷*.()]", "", WORKING_LABEL_RE.sub("", text).lower())


def line_recall(expected: list[str], transcription: str) -> tuple[int, list[str]]:
    got = [norm(l) for l in transcription.splitlines() if norm(l)]
    joined = "".join(got)
    hit, missing = 0, []
    for line in expected:
        n = norm(line)
        best = max((difflib.SequenceMatcher(None, n, g).ratio() for g in got), default=0)
        # a wrapped question may be split over two transcribed lines
        best = max(best, difflib.SequenceMatcher(None, n, joined).find_longest_match(0, len(n), 0, len(joined)).size / max(len(n), 1))
        if best >= 0.9:
            hit += 1
        else:
            missing.append(line)
    return hit, missing


def math_tokens(text: str) -> list[str]:
    return re.findall(r"\d+(?:[.,]\d+)*|[+\-=/^÷]|\bx\b|sqrt", WORKING_LABEL_RE.sub("", text).replace("×", "x").replace("*", "x"))


def math_ok(expected: list[str], transcription: str) -> bool:
    want = math_tokens(" ".join(expected))
    have = math_tokens(transcription)
    it = iter(have)
    return all(any(t == h for h in it) for t in want)  # in order, extra tokens allowed


def search(text: str, topic: str, grade: str | None, subject: str | None):
    """The service's photo search: topic phrase + the questions, then the usual query steps."""
    raw = photo_search_text(topic, strip_student_working(text) or text)
    q = expand_student_terms(correct_spelling(build_retrieval_query(raw), curriculum_vocabulary()))
    return retrieve(q, grade, subject, top_k=3)


def topic_hit(records, pattern: str) -> bool:
    rx = re.compile(pattern, re.I)
    return any(rx.search(f"{r['indicator_text']} {r.get('content_standard_text', '')} {r['substrand']}") for r in records)


def mime(path: Path) -> str:
    return {"png": "image/png", "webp": "image/webp"}.get(path.suffix.lower().lstrip("."), "image/jpeg")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--real", action="store_true", help="also run photos in eval/ocr/real/")
    ap.add_argument("--only", nargs="*", help="file stems to run")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    cases = []
    for entry in json.loads((HERE / "worksheets" / "manifest.json").read_text()):
        cases.append((HERE / "worksheets" / entry["file"], entry, "synthetic"))
    if args.real:
        for img in sorted((HERE / "real").glob("*")):
            if img.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"):
                side = img.with_suffix(".json")
                cases.append((img, json.loads(side.read_text()) if side.exists() else {}, "real"))
    if args.only:
        cases = [c for c in cases if c[0].stem in args.only]

    llm = get_llm_provider()
    totals = {k: [0, 0] for k in ("lines", "math", "working", "refused", "topic", "no_false_alarm")}
    rows = []
    for path, meta, origin in cases:
        scan = llm.transcribe_image(path.read_bytes(), mime(path))
        text, unreadable = scan.text, scan.unreadable
        row = {"file": path.name, "origin": origin, "transcription": text, "topic": scan.topic}

        if meta.get("expect_unreadable"):
            # Acceptable: refuse, or ask the student to confirm. Not acceptable: tutoring
            # confidently from text the model made up.
            row["refused"] = unreadable or scan.needs_confirmation
            totals["refused"][0] += row["refused"]
            totals["refused"][1] += 1
        else:
            exp = meta.get("expected_lines")
            if exp:
                hit, missing = line_recall(exp, text)
                row.update(lines=f"{hit}/{len(exp)}", missing=missing, math=math_ok(exp, text))
                totals["lines"][0] += hit == len(exp)
                totals["lines"][1] += 1
                totals["math"][0] += row["math"]
                totals["math"][1] += 1
            if meta.get("has_working"):
                row["working"] = bool(WORKING_LABEL_RE.search(text))
                totals["working"][0] += row["working"]
                totals["working"][1] += 1
            if meta.get("expected_lines") and not unreadable:
                row["no_false_alarm"] = not scan.needs_confirmation  # clear sheet: don't ask to confirm
                totals["no_false_alarm"][0] += row["no_false_alarm"]
                totals["no_false_alarm"][1] += 1
            if not unreadable and not scan.needs_confirmation:
                found = search(text, scan.topic, meta.get("grade"), meta.get("subject"))
                row["codes"] = [r["indicator_code"] for r in found]
                if meta.get("expect_topic"):
                    row["topic"] = topic_hit(found, meta["expect_topic"])
                    totals["topic"][0] += row["topic"]
                    totals["topic"][1] += 1
            elif exp:
                row["refused"] = "UNEXPECTED UNREADABLE"
        rows.append(row)

        flags = " ".join(
            f"{k}={'ok' if v is True else ('FAIL' if v is False else v)}"
            for k, v in row.items()
            if k in ("lines", "math", "working", "refused", "topic", "no_false_alarm")
        )
        print(f"{path.name:34} {flags}")
        if args.verbose or row.get("missing") or row.get("math") is False or not meta:
            print("    transcription:", text.replace("\n", " | ")[:300])
            print("    topic:", scan.topic)
            if row.get("missing"):
                print("    missing lines:", row["missing"])
            if row.get("codes"):
                print("    top-3 codes:", row["codes"])

    print("\nSUMMARY (synthetic + real with ground truth)")
    for k, (ok, n) in totals.items():
        if n:
            print(f"  {k:8} {ok}/{n}")
    (HERE / "last_report.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
