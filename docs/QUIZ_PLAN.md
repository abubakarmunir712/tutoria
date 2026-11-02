# Quizzes, Assignments, Diagnostics and Mastery — Implementation Plan

Source: `docs/sources/production-knowledge-base.xlsx` (consultant pack, sheets 4–7) and
`docs/sources/curriculum-content-delivery.pdf` (unit design: four-part assessment, remediation,
mastery = more than one example + unfamiliar transfer). Placed in Milestone 3 (XP is meant to be
tied to quiz/assignment completion).

## 1. Content model

The pack has 450 **practice units** (`TUT-001`…): 9 grades × 5 subjects × 10 units. Each unit has
5 questions (one per level: Foundational → Problem Solving / Transfer, difficulty 1–5), 3
diagnostic items (the first three questions + remediation guidance), 1 assignment and a
progression entry (previous / next learning, mastery states).

- Units are **not** the NaCCA sub-strands the tutor teaches from, so they are their own list
  ("Practice" on the Learn tab) rather than being force-mapped onto the Qdrant topics.
- The pack's subject names differ from the app's: `English` → English Language,
  `Computing / AI / Coding` → Computing, and Upper Primary `Social Studies` → Our World and Our People.
- Data quality (flagged earlier by the team): content is templated, only 329 of 2,250 questions are
  distinct, and some `expected_answer`s are instructions, not answers ("Use the place-value names…").
  So grading cannot be string-match only.

## 2. Data pipeline

`scripts/build_quiz_bank.py` reads the xlsx (stdlib only) → `server/prisma/data/quiz-bank.json`
(committed, so the server has no xlsx dependency). `server/prisma/seed-quiz.ts` upserts it into
Postgres (idempotent; `npm run quiz:seed`).

## 3. Database (Prisma)

| Model | Purpose |
|---|---|
| `QuizTopic` | unit: code, grade, subject, name, term, week, order, previous/next learning, remediation text, assignment (task, success criteria, reflection prompt) |
| `QuizQuestion` | topic, level, order, question, expected answer, variations, wrong answer, misconception tag, worked solution, difficulty, rubric, diagnostic remediation fields |
| `QuizAttempt` | student, topic, mode (QUIZ / CHECK), started/finished, score, xp earned |
| `QuizAnswer` | attempt, question, answer text, tries (1–2), verdict, points, feedback |
| `TopicMastery` | student × topic: state, attempts, best/last score, last attempt time |
| `AssignmentSubmission` | student × topic: response, reflection, verdict, feedback, xp |
| enums | `EventKind` += QUIZ, CHECK, ASSIGNMENT; `UsageKind` += GRADE; `MasteryState`; `QuizMode`; `Verdict` |
| `StudentStats` | += quizzes, assignments, perfectQuizzes, masteredTopics |

## 4. Grading (AI service `POST /grade`)

1. Server tries a deterministic check first: normalised text / number equality with the expected
   answer or its variations → CORRECT without an AI call (cheap, fast, offline-safe).
2. Otherwise the AI service grades the learner's answer against the question, expected answer,
   rubric and (for placeholder answers) its own subject knowledge → `correct | partial | incorrect`
   + a short, child-friendly nudge that **does not reveal the answer**.
3. If the AI service is unreachable, a keyword-overlap fallback decides and the call is flagged.
4. Every AI grade is written to `UsageLog` (kind `GRADE`) so cost/rate limits cover it.
5. Assignments use the same endpoint with the success criteria as the rubric.

## 5. Quiz flow (server `/quiz`)

- `GET  /quiz/topics?studentId&subject` — units for the learner's grade + subject, with mastery state,
  best score, assignment status, recommended next unit.
- `POST /quiz/attempts {studentId, topicId, mode}` — start (or resume) an attempt; QUIZ = 5 questions,
  CHECK (diagnostic) = first 3. Answers are never sent with questions.
- `POST /quiz/attempts/:id/answer {questionId, answer}` — two tries per question. Wrong first try →
  nudge + retry. Final → reveals the answer, worked solution and remediation. Last answer finishes
  the attempt and returns the result.
- `GET  /quiz/attempts/:id` — resume / review.
- `GET  /quiz/progress?studentId` — mastery overview per subject (Progress tab, parent view).
- `GET/POST /quiz/assignments/...` — view and submit an assignment.

Points per question: correct first try 1.0, correct on retry 0.6, partial 0.5, wrong 0. Score = sum / count.

## 6. Mastery (pure functions, unit-tested)

States (from the pack's progression map): Not Started → Emerging → Developing → Secure → Mastered →
Needs Revision. Score ≥ 50% Developing, ≥ 80% Secure; **Mastered** needs two attempts ≥ 80% *and* the
transfer question (level 5) correct on the latest — "more than one example and unfamiliar transfer".
A learner who was Secure/Mastered and scores < 50% drops to Needs Revision. Diagnostics (CHECK) can
raise a Not Started unit to at most Developing.

## 7. XP and badges

- First finish of a unit: 10 + 30 × score. Repeats pay only the improvement (30 × (score − best)),
  so replaying can't farm XP. Diagnostics: half. Assignment: 20 (meets criteria) / 10 (developing).
- Streaks, first-of-day bonus and the daily event cap apply as for questions.
- New badges: Quiz Starter, Perfect Score, Quiz Whiz (10 quizzes), Topic Master (first Mastered),
  Homework Hero (first assignment). Quizzes do not count as "questions asked".

## 8. App (Flutter)

Learn tab → subject → **Practice** list (unit, mastery chip, best score, Quiz / Quick check /
Assignment) → question screen (progress bar, text answer, nudge + retry, reveal) → result screen
(score, XP, level-up/badges via the existing reward toast, what to revise, next unit, "Ask the tutor
about this"). Progress tab gets a mastery section; the parent's child view shows mastery per subject.

## 9. Admin

Overview gets quiz figures (attempts, average score, mastered units); a "Learning" page lists the
hardest units (lowest average score) and the most common misconception tags.

## 10. Tests / acceptance

Jest for mastery + XP + answer matching; Python unittest for the grade fallback/parsing; Flutter
widget test for the quiz flow; an end-to-end smoke test against the local server (signup → start quiz
→ answer → result → progress). Docs: PRD ticked, change-log entry, deploy notes (seed step).
