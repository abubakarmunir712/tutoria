# Tutoria (Homework Buddy AI) — Product Requirements Document

**Client:** Joel
**Curriculum:** Ghana NaCCA — Primary 4–6 (B4–B6), JHS 1–3 (B7–B9), SHS 1–3
**Platform:** Native Android & iOS (Flutter)
**Status:** Milestone 1 paid and active

---

## 1. Project Overview

Tutoria is an AI-powered homework tutor app for Ghanaian students, grounded in the official NaCCA curriculum. The AI tutor retrieves curriculum-aligned content (via RAG) before answering, so every response is traceable to an official Strand/Sub-strand/Content Standard/Indicator code — not generic AI output.

**Phase 1 vision (what this whole project actually is):** student app + homework companion + curriculum engine. Voice interaction and gamification were the client's own Phase 2 items — they show up here as later milestones, not core M1/M2 scope.

## 2. Curriculum Scope

| Phase | Grades | NaCCA Code |
|---|---|---|
| Upper Primary | Primary 4–6 | B4–B6 |
| JHS | JHS 1–3 | B7–B9 |
| SHS | SHS 1–3 | (separate SHS labeling) |

**Subjects (5 per phase):**
- Mathematics
- English Language
- Science
- Our World and Our People (Primary) / Social Studies (JHS, SHS)
- Computing / AI / Coding

**Curriculum hierarchy to model:**
Grade → Subject → Strand → Sub-strand → Content Standard → Indicator → Official Indicator Code → Content/Exemplar

**Source of truth:** Official NaCCA PDFs (supersede consultant-provided xlsx/PDF packs, which have placeholder `VERIFY OFFICIAL CODE` markers).

Official curriculum landing pages:
- Primary 4–6: https://nacca.gov.gh/learning-areas-subjects/new-standards-based-curriculum-2019/
- JHS 1–3: https://nacca.gov.gh/common-core-programme-ccp/
- SHS 1–3: https://nacca.gov.gh/secondary-education-curriculum/

Direct PDFs confirmed so far (Upper Primary B4–B6):
- Math: https://nacca.gov.gh/wp-content/uploads/2019/04/MATHS-UPPER-PRIMARY-B4-B6.pdf
- Science: https://nacca.gov.gh/wp-content/uploads/2019/04/SCIENCE-UPPER-PRIMARY-B4-B6.pdf
- English: https://nacca.gov.gh/wp-content/uploads/2019/04/ENGLISH-UPPER-PRIMARY-B4-B6.pdf
- Computing: https://nacca.gov.gh/wp-content/uploads/2019/04/COMPUTING-B4-B6.pdf
- (JHS/SHS equivalents + remaining subjects: locate as needed per milestone)

**Existing content assets (consultant-provided, need code verification):**
- `Tutoria_PRODUCTION_KNOWLEDGE_BASE` (xlsx) — 9 linked sheets: Curriculum Map, Lesson Content, AI Dialogue (3,150 rows), Assessment Bank (2,250 rows), Diagnostic/Remediation (1,350 rows), Assignments, Progression Map, Sources, QA Checklist. 450 sessions total (9 grades × 5 subjects × 10 topics).
- `Tutoria_Client_Delivery_FINAL_TOPIC_REVISED` (420-page PDF) — expanded prose version of the same 450 units, grade-specificity checked, indicator codes still placeholders pending official verification.
- **Known caveat:** earlier draft had templated per-grade content (same explanation scaled by number); revised version claims to fix this. Neither has verified official indicator codes yet — that's a standing gate before anything is "exam-safe."

## 3. Core Functional Requirements (priority order, excluding gamification)

1. **Student Profile & Auth** — account, grade-level selection, subject enrollment
2. **AI Tutor Chat** — curriculum-grounded Q&A, text + voice (English only), RAG retrieval before every response
3. **Homework Upload + OCR** — photo/upload → OCR extract → curriculum-matched AI response
4. **Curriculum-Aligned Lesson Delivery** — structured per-topic walkthrough: content → worked example → guided practice → independent practice
5. **Quizzes/Assessments** — topic-linked items, scored, tied to indicator codes
6. **Assignments** — homework-style tasks distinct from quizzes
7. **Diagnostics + Remediation** — gap detection, reteach + corrected example + new practice
8. **Progress/Progression Tracking** — prior → current → next topic sequencing, mastery status
9. *(Secondary)* Gamification — XP, streaks, badges, leaderboards
10. *(Secondary)* Admin & Telemetry Dashboard — engagement, API cost per session, usage patterns, rate-limiting

## 4. Non-Functional Requirements

- **Voice:** English only at launch (curriculum is English-based)
- **Deployment:** Native Android + iOS via Flutter (client decision — PWA was recommended, deferred by client, may revisit post-launch)
- **Devices:** ~80% Android, ~20% iPhone; ~80% tablets/phones — build mobile-first, not desktop-first
- **Payment:** Mobile Money via Telco API — client-side integration, separate track, docs pending from Joel
- **Store setup:** Apple Developer account started early (longest approval lead time); Android can distribute via APK pre-launch without Play Store; Joel handles his-side actions with developer guidance
- **Cost control:** API cost per session must be tracked and rate-limited (see M4 bonus dashboard) to guard against unexpected spend

---

## 5. Milestone Roadmap (Full Project)

This is the client-facing, weeks-based breakdown (see [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) — this is the authoritative milestone structure; it supersedes an earlier draft numbering that shipped with this PRD). Sub-tasks below are the engineering-level detail behind each milestone line.

### MILESTONE 1 — Foundation, Design Direction, and Authentication — Weeks 1–2
**Goal:** Production Flutter environment stood up, app flow/design direction locked, real student auth + profile data layer working, dashboard scaffold + navigation in place, and the first curriculum slice ingested and ready for the AI pipeline to consume in M2.

**Curriculum test slice:** Primary 4–6 Mathematics *(update if changed)*

- [ ] **1. Flutter environment** — production setup for native Android + iOS targets (`app/` already scaffolded — confirm build config, signing, flavors as needed)
- [ ] **2. Design direction & app flow** — screen flows, navigation structure, brand application (Tutoria palette, logo already received)
- [ ] **3. Authentication**
  - [ ] Student signup/login (email or phone-based, per Mobile Money market norms)
  - [ ] Session/token management
- [ ] **4. Student profile data layer**
  - [ ] Grade-level selection
  - [ ] Subject enrollment (multi-subject support)
  - [ ] Profile persistence in DB
- [ ] **5. Dashboard scaffold + navigation structure** (student-facing shell, not the full dashboard — that's M3)
- [ ] **6. Curriculum ingestion — one grade/subject slice, ready for the AI pipeline**
  - [ ] Download official NaCCA PDF — MATHS-UPPER-PRIMARY-B4-B6.pdf (link above)
  - [ ] Extract text with layout awareness (pdfplumber)
  - [ ] Regex out indicator codes (pattern: `B\d{1,2}(\.\d+){2,4}`)
  - [ ] Parse hierarchy sequentially (Strand → Sub-strand → Content Standard → Indicator)
  - [ ] Output structured JSON records (grade, strand, substrand, content_standard, indicator_code, indicator_text, exemplar)
  - [ ] Cross-check against consultant content (xlsx / 420-page PDF), replace `VERIFY OFFICIAL CODE` placeholders with verified codes (this slice only)
  - [ ] Embed indicator_text + exemplar and load into **Qdrant** (vector DB decision — see brief), with grade/subject/strand/code as metadata filters
  - [ ] Sanity-check retrieval in a script/terminal (student question → filtered retrieval → context) — this is *readiness*, not the production RAG chat integration, which happens in M2

**Explicitly OUT of scope for M1:** full 9-grade/5-subject ingestion, RAG tutor chat wired into the app, OCR, voice, gamification, admin dashboard.

---

### MILESTONE 2 — AI Core, Curriculum RAG, and Voice Pipeline — Weeks 3–5
**Goal:** Wire the AI tutor to the curriculum in Qdrant, add homework OCR, ship real-time voice, and pick the production AI config.

- [ ] **1. AI tutor ↔ curriculum RAG (Socratic approach)**
  - [ ] Student question → filtered retrieval (grade/subject) → context-injected AI response, integrated into the app (not just terminal)
  - [ ] Production-grade retrieval (reranking, multi-turn context, conversation memory)
  - [ ] Grounding checks / citation of indicator code in responses
- [ ] **2. Homework OCR**
  - [ ] Image upload → OCR extract → cross-referenced against curriculum → same RAG path as chat
- [ ] **3. Voice pipeline**
  - [ ] STT (speech-to-text) for student input, English only
  - [ ] TTS (text-to-speech) for AI responses, English only
  - [ ] Latency/cost testing for voice round-trip
- [ ] **4. Model & cost review** — compare model/provider options for the production AI config, factoring in per-session cost

**Dependency:** needs Joel's confirmed priority subjects beyond the M1 test slice if ingestion is to expand here; generalizing the M1 ingestion script into a repeatable pipeline for those subjects belongs in this milestone.

---

### MILESTONE 3 — Gamification and Dashboard — Weeks 6–7
**Goal:** Add the engagement layer and complete the student + admin dashboards.

- [ ] **1. Gamification**
  - [ ] XP system tied to quiz/assignment completion, with backend persistence
  - [ ] Streaks
  - [ ] Rewards screen
  - [ ] (Badges/leaderboards — confirm with Joel if in scope, see Open Items)
- [ ] **2. Complete student dashboard** — builds on the M1 scaffold: "continue where you left off," subject/grade navigation, progress view
- [ ] **3. Admin & telemetry dashboard** (`admin/` already scaffolded)
  - [ ] Real-time visibility into student engagement
  - [ ] API cost per session tracking
  - [ ] Usage pattern analytics
  - [ ] Rate-limiting controls to guard against API cost spikes

---

### MILESTONE 4 — Native Packaging, Cross-Platform QA, and Launch — Week 8
**Goal:** Package, test, and ship.

- [ ] **1. Native packaging** — Android + iOS release builds
- [ ] **2. Native push notifications + store assets**
- [ ] **3. Payment integration** — Mobile Money (Telco API), client-side, test transactions end-to-end
- [ ] **4. Store submission** — Apple App Store (account started early) + Google Play Store
- [ ] **5. Cross-platform QA** — end-to-end testing across both platforms, load/cost testing under real usage
- [ ] **6. Launch & handover**

---

### ⚠️ Unplaced from Section 3's functional requirements

**Quizzes/Assessments, Assignments, Diagnostics + Remediation, and Progression Tracking** (Section 3, items 5–8) aren't explicitly placed in the weeks-based milestone plan above — the client-facing brief doesn't mention them by milestone. They most naturally extend M2 (learning loop) or M3 (dashboard needs progression data to show), but **this needs Joel/team confirmation** rather than a guess baked into the plan silently. Tracked in Open Items below.

---

## 6. Open Items / Blockers (Track Across All Milestones)

- [ ] Mobile Money API docs (waiting on Joel) — blocks M4 payment work
- [ ] Apple Developer account setup (Joel-side action, developer to guide) — start early, blocks M4 store submission
- [ ] Curriculum accuracy/SME sign-off pass (separate from code verification) — needed before any "exam-safe" claim, ongoing across M1–M3 as more subjects are ingested
- [ ] Confirm which 1–2 subjects Joel wants prioritized for full build beyond the M1 test slice — blocks start of M2 full ingestion
- [ ] Confirm whether SHS curriculum PDFs follow the same direct-link pattern as B4–B6/B7–B9 (not yet verified)
- [ ] Confirm if leaderboards are in scope for M4 or explicitly out
- [ ] Confirm which milestone owns Quizzes/Assessments, Assignments, Diagnostics + Remediation, and Progression Tracking (Section 3, items 5–8) — not placed in the weeks-based roadmap (Section 5)

---

## 7. Change Log

*Log milestone completions, scope changes, and client decisions here as they happen.*

- [Date] — Milestone 1 test slice confirmed: Primary 4–6 Mathematics
