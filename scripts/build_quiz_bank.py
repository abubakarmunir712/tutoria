#!/usr/bin/env python3
"""Turn the consultant's knowledge-base workbook (docs/sources/production-knowledge-base.xlsx)
into server/prisma/data/quiz-bank.json, which `npm run quiz:seed` loads into Postgres.

Standard library only (an .xlsx is a zip of XML), so it runs anywhere:
    python3 scripts/build_quiz_bank.py
"""

import html
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/sources/production-knowledge-base.xlsx"
OUT = ROOT / "server/prisma/data/quiz-bank.json"

GRADES = {
    "Primary 4": "B4", "Primary 5": "B5", "Primary 6": "B6",
    "JHS 1": "B7", "JHS 2": "B8", "JHS 3": "B9",
    "SHS 1": "SHS1", "SHS 2": "SHS2", "SHS 3": "SHS3",
}
LEVELS = {
    "Foundational": "FOUNDATIONAL", "Understanding": "UNDERSTANDING", "Application": "APPLICATION",
    "Reasoning": "REASONING", "Problem Solving / Transfer": "TRANSFER",
}


def subject_name(subject: str, grade: str) -> str:
    """The workbook's subject names -> the names the app and the subject table use."""
    if subject == "English":
        return "English Language"
    if subject == "Computing / AI / Coding":
        return "Computing"
    if subject == "Social Studies" and grade.startswith("Primary"):
        return "Our World and Our People"
    return subject


def read_sheets(path: Path) -> dict[str, list[dict]]:
    z = zipfile.ZipFile(path)
    names = re.findall(r'<sheet [^>]*name="([^"]+)"', z.read("xl/workbook.xml").decode())
    strings = [
        html.unescape(re.sub(r"<[^>]+>", "", m))
        for m in re.findall(r"<si>(.*?)</si>", z.read("xl/sharedStrings.xml").decode(), re.S)
    ]
    sheets = {}
    for i, name in enumerate(names, 1):
        xml = z.read(f"xl/worksheets/sheet{i}.xml").decode()
        rows = []
        for r in re.findall(r"<row [^>]*>(.*?)</row>", xml, re.S):
            row = {}
            for m in re.finditer(r'<c r="([A-Z]+)\d+"([^>]*?)(?:/>|>(.*?)</c>)', r, re.S):
                col, attrs, body = m.groups()
                v = re.search(r"<v>(.*?)</v>", body or "", re.S)
                if v:
                    row[col] = strings[int(v.group(1))] if 't="s"' in attrs else v.group(1)
            rows.append(row)
        if rows:
            head = rows[0]
            sheets[name] = [{head[c]: r.get(c, "").strip() for c in head} for r in rows[1:] if r]
    return sheets


def main() -> int:
    sheets = read_sheets(SRC)
    cmap = sheets["1_Curriculum_Map"]
    bank = sheets["4_Assessment_Bank"]
    diag = sheets["5_Diagnostic_Remediation"]
    asg = {r["record_id"]: r for r in sheets["6_Assignments"]}
    prog = {r["record_id"]: r for r in sheets["7_Progression_Map"]}

    questions_by, diag_by = {}, {}
    for q in bank:
        questions_by.setdefault(q["record_id"], []).append(q)
    for d in diag:
        diag_by.setdefault(d["record_id"], []).append(d)

    topics, order = [], {}
    for rec in cmap:
        rid = rec["record_id"]
        grade = GRADES[rec["grade"]]
        subject = subject_name(rec["subject"], rec["grade"])
        order[(grade, subject)] = order.get((grade, subject), 0) + 1

        qs = sorted(questions_by[rid], key=lambda q: int(q["difficulty"]))
        if len(qs) != 5:
            sys.exit(f"{rid}: expected 5 questions, found {len(qs)}")
        diags = {d["diagnostic_question"]: d for d in diag_by.get(rid, [])}
        first_diag = (diag_by.get(rid) or [{}])[0]

        questions = []
        for n, q in enumerate(qs, 1):
            d = diags.get(q["question"], {})
            questions.append({
                "order": n,
                "level": LEVELS[q["level"]],
                "difficulty": int(q["difficulty"]),
                "question": q["question"],
                "expectedAnswer": q["expected_answer"],
                "variations": q["acceptable_variations"],
                "commonWrongAnswer": q["common_wrong_answer"],
                "misconception": q["misconception_tag"],
                "hints": [h for h in (q["hint_1"], q["hint_2"], q["hint_3"]) if h],
                "workedSolution": q["worked_solution"],
                "rubric": q["rubric"],
                # Only the first three questions are also diagnostic items.
                "diagnostic": bool(d),
            })

        a = asg.get(rid, {})
        p = prog.get(rid, {})
        topics.append({
            "code": rid,
            "grade": grade,
            "subject": subject,
            "name": rec["topic"],
            "strand": rec["strand"],
            "term": rec["term"],
            "week": int(rec["week"] or 0),
            "order": order[(grade, subject)],
            "previousLearning": p.get("previous_learning") or rec["previous_learning"],
            "nextLearning": p.get("next_learning") or rec["next_learning"],
            "remediation": first_diag.get("remediation", ""),
            "alternativeExplanation": first_diag.get("alternative_explanation", ""),
            "prerequisiteRevision": first_diag.get("prerequisite_revision", ""),
            "likelyMisconception": first_diag.get("likely_misconception", ""),
            "assignment": {
                "task": a.get("assignment", ""),
                "successCriteria": a.get("success_criteria", ""),
                "reflectionPrompt": a.get("reflection_prompt", ""),
            },
            "questions": questions,
        })

    OUT.write_text(json.dumps({"source": SRC.name, "topics": topics}, ensure_ascii=False, indent=1) + "\n")
    print(f"{len(topics)} units, {sum(len(t['questions']) for t in topics)} questions -> {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
