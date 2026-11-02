"""
Marking a learner's written answer (quiz questions and assignments) with the LLM.

The prompt and the parsing live here, apart from any provider, so they can be tested without a
model. A provider only has to return JSON text for a system + user prompt (`generate_json`).
"""

import json
import re

VERDICTS = ("correct", "partial", "incorrect")

QUESTION_SYSTEM = """You mark answers from Ghanaian school children (Class 4 to SHS 3) for a friendly tutor app.

You get a question, a REFERENCE answer, a marking rubric and the child's answer. The reference
answer is sometimes only guidance (for example "Use the place-value names from the highest digit
to the lowest") rather than a real answer. When it is guidance, work out the correct answer
yourself from the question and mark against that.

Mark for meaning, not wording: accept a different but correct way of saying it, spelling slips,
and correct numbers written in another form (1,000 / 1000 / one thousand). Be strict about wrong
facts and wrong numbers.

verdict:
- "correct": the answer is right (and gives the reasoning the question asks for).
- "partial": the idea or method is right but there is a slip, or the answer is incomplete.
- "incorrect": wrong, off-topic, or empty of real content.

feedback: one or two short, kind sentences for the child, in simple English.
- If correct: say what they got right.
- If partial or incorrect: give a gentle nudge toward the right idea. NEVER state the correct
  answer or give the final number, because the child may try again.
Reply with JSON only: {"verdict": "correct"|"partial"|"incorrect", "feedback": "..."}"""

ASSIGNMENT_SYSTEM = """You give feedback on a written assignment from a Ghanaian school child (Class 4 to SHS 3).

You get the task, the SUCCESS CRITERIA, the child's response and their short reflection. Judge
only against the success criteria.

verdict:
- "correct": the response meets the criteria (a genuine, on-task attempt that shows the required
  steps / reasoning).
- "partial": a real attempt that meets some criteria but is missing steps, reasoning or accuracy.
- "incorrect": off-task, copied text, or too little to judge.

feedback: two to four short, kind sentences in simple English: one thing done well, then one or
two specific things to improve. Do not rewrite the work for the child.
Reply with JSON only: {"verdict": "correct"|"partial"|"incorrect", "feedback": "..."}"""


def question_prompt(
    *,
    question: str,
    expected_answer: str,
    rubric: str,
    student_answer: str,
    grade: str | None,
    subject: str | None,
    first_try: bool,
) -> str:
    where = " ".join(p for p in (grade, subject) if p)
    return (
        f"Level: {where or 'school'}\n"
        f"Question: {question}\n"
        f"Reference answer: {expected_answer}\n"
        f"Rubric: {rubric}\n"
        f"This is the child's {'first' if first_try else 'second and last'} try.\n"
        f"Child's answer: {student_answer}"
    )


def assignment_prompt(
    *,
    task: str,
    success_criteria: str,
    response: str,
    reflection: str,
    grade: str | None,
    subject: str | None,
) -> str:
    where = " ".join(p for p in (grade, subject) if p)
    return (
        f"Level: {where or 'school'}\n"
        f"Task: {task}\n"
        f"Success criteria: {success_criteria}\n"
        f"Child's response: {response}\n"
        f"Child's reflection: {reflection or '(none)'}"
    )


def parse_grade(raw: str) -> dict:
    """{'verdict', 'feedback'} from the model's reply. Anything unusable becomes a clear error
    (ValueError) so the caller can fall back, never a guessed mark."""
    text = (raw or "").strip()
    fence = re.search(r"\{.*\}", text, re.S)
    if not fence:
        raise ValueError("no JSON in grader reply")
    data = json.loads(fence.group(0))
    verdict = str(data.get("verdict", "")).strip().lower()
    if verdict not in VERDICTS:
        raise ValueError(f"bad verdict: {verdict!r}")
    return {"verdict": verdict, "feedback": str(data.get("feedback", "")).strip()[:600]}
