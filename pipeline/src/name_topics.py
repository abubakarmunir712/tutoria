"""
Give proper short topic titles to sub-strands the PDFs left unnamed or named ambiguously.

A group needs a name when the extractor had to infer it (no header of its own in the PDF) or when
another group in the same strand has the identical name. The model proposes a 1-4 word,
student-friendly title for each, seeing the strand, the sibling topic names and the group's
content standard and indicators. Names are saved to data/topic_names.json (commit it; review it)
and reapplied by ingest_all.py on every extraction.

Run (from pipeline/, needs GEMINI_API_KEY in the repo-root .env):
  python src/name_topics.py --records-dir /tmp/extracted   # JSON from ingest_all.py --extract-only
  python src/name_topics.py --dry-run                      # list what would be named, no API calls
"""

import argparse
import json
import os
import re
import time
from collections import defaultdict
from pathlib import Path

from dotenv import load_dotenv

from topic_names import NAMES_PATH, group_key, load_names

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT.parent / ".env")

GRADE_NAMES = {"B4": "Primary 4", "B5": "Primary 5", "B6": "Primary 6", "B7": "JHS 1", "B8": "JHS 2", "B9": "JHS 3"}


def norm(name: str) -> str:
    return re.sub(r"\W+", " ", name.lower()).strip()


def units_needing_names(records: list[dict]) -> dict[tuple[str, str], list[dict]]:
    """{(group code, current name): records} for the sections to name: those whose name the
    extractor inferred, and those sharing a name with another group in the same strand."""
    units: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for r in records:
        units[(".".join(r["indicator_code"].split(".")[:3]), r["substrand"])].append(r)

    needs = {u for u, rs in units.items() if any(r.get("substrand_inferred") for r in rs)}
    by_strand: dict[tuple, dict[str, set]] = defaultdict(lambda: defaultdict(set))
    for (code, name) in units:
        grade, strand_no, _ = code.split(".")
        by_strand[(grade, strand_no)][norm(name)].add(code)
    for (code, name) in units:
        grade, strand_no, _ = code.split(".")
        if len(by_strand[(grade, strand_no)][norm(name)]) > 1:  # two groups, one name
            needs.add((code, name))
    order = lambda u: [int(p) if p.isdigit() else 0 for p in re.split(r"\.|B", u[0])]
    return {u: units[u] for u in sorted(needs, key=order)}


def build_prompt(subject: str, grade: str, strand: str, todo: dict[str, list[dict]], siblings: list[str]) -> str:
    items = []
    for (code, name), rs in todo.items():
        cs = next((r["content_standard_text"] for r in rs if r["content_standard_text"]), "")
        items.append(
            {
                "id": f"{code}|{name}",
                "current_name": name,
                "content_standard": cs[:240],
                "indicators": [r["indicator_text"][:140] for r in rs[:6]],
            }
        )
    return (
        f"You name topics in a children's learning app built on Ghana's NaCCA curriculum.\n"
        f"Subject: {subject}. Class: {GRADE_NAMES.get(grade, grade)}. Strand: {strand}.\n"
        f"Topics already named in this strand (match their style): {siblings or 'none'}.\n\n"
        "Give each group below a short topic title: 1 to 4 words, Title Case, plain words a child or "
        "parent would recognise (like 'Fractions', 'Number Operations', 'Plants and Animals'). It must say "
        "what the lessons are about, and every title in this strand must be different from the others "
        "and from the existing names above. Do not include the class, the subject, or numbers.\n\n"
        f"Groups:\n{json.dumps(items, ensure_ascii=False, indent=1)}\n\n"
        'Reply as JSON: {"names": [{"id": "<id>", "title": "<title>"}]}'
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--records-dir", default=str(ROOT / "data" / "structured"))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true", help="re-name groups that already have a stored name")
    args = ap.parse_args()

    stored = load_names()
    plan = []  # (slug, grade, strand, subject, todo, siblings)
    for path in sorted(Path(args.records_dir).glob("*.json")):
        slug = path.stem
        if slug.endswith("-shs"):
            continue  # SHS sub-strand names come from real headers
        records = json.loads(path.read_text())
        todo_all = {
            u: rs
            for u, rs in units_needing_names(records).items()
            if args.force or group_key(slug, rs[0]["indicator_code"], u[1]) not in stored
        }
        if not todo_all:
            continue
        by_strand: dict[tuple, dict] = defaultdict(dict)
        for (code, name), rs in todo_all.items():
            by_strand[(code.split(".")[0], code.split(".")[1])][(code, name)] = rs
        for (grade, strand_no), todo in by_strand.items():
            siblings = sorted(
                {
                    r["substrand"]
                    for r in records
                    if r["indicator_code"].startswith(f"{grade}.{strand_no}.")
                    and (".".join(r["indicator_code"].split(".")[:3]), r["substrand"]) not in todo
                }
            )
            first = next(iter(todo.values()))[0]
            plan.append((slug, grade, first["strand"], first["subject"], todo, siblings))

    print(f"{sum(len(p[4]) for p in plan)} sections to name in {len(plan)} strands")
    if args.dry_run:
        for slug, grade, strand, subject, todo, siblings in plan:
            for (code, name), rs in todo.items():
                print(f"  {slug:42} {code:9} now: {name[:50]!r} ({len(rs)} records, inferred={rs[0].get('substrand_inferred')})")
        return

    from google import genai
    from google.genai import types
    from pydantic import BaseModel

    class Title(BaseModel):
        id: str
        title: str

    class Titles(BaseModel):
        names: list[Title]

    client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    model = os.environ.get("GEMINI_MODEL", "gemini-3.5-flash-lite")
    names = dict(stored)
    for slug, grade, strand, subject, todo, siblings in plan:
        prompt = build_prompt(subject, grade, strand, todo, siblings)
        for attempt in range(6):
            try:
                response = client.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=types.GenerateContentConfig(temperature=0, response_mime_type="application/json", response_schema=Titles),
                )
                break
            except Exception as exc:  # network blips and rate limits: wait and retry
                if attempt == 5:
                    raise
                # Rate limits (the free Gemini tier allows 15 requests a minute) say how long to wait.
                wait = 35 if "429" in str(exc) else 3 * (attempt + 1)
                print(f"  (waiting {wait}s after {type(exc).__name__})")
                time.sleep(wait)
        by_id = {f"{code}|{name}": (code, name, rs) for (code, name), rs in todo.items()}
        for item in json.loads(response.text)["names"]:
            if item["id"] in by_id and item["title"].strip():
                code, name, rs = by_id[item["id"]]
                key = group_key(slug, rs[0]["indicator_code"], name)
                names[key] = title_case(item["title"])
                print(f"  {key:52} -> {names[key]}")
        # save after every strand, so an interrupted run keeps what it has done
        NAMES_PATH.write_text(json.dumps(dict(sorted(names.items())), indent=2, ensure_ascii=False) + "\n")
    print(f"saved {len(names)} names to {NAMES_PATH}")


def title_case(title: str) -> str:
    """'Desktop And Folders' -> 'Desktop and Folders' (same rule the topic list uses)."""
    words = " ".join(title.split()).split(" ")
    small = {"and", "of", "the", "in", "to", "for", "a", "an", "on", "with", "as", "at", "or"}
    return " ".join(w.lower() if (i and w.lower() in small) else w[:1].upper() + w[1:] for i, w in enumerate(words))


if __name__ == "__main__":
    main()
