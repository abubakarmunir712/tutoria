# Tutoria — Project Brief

Client-facing context and decisions, extracted from the client thread (full raw log: [`raw/client-thread.txt`](raw/client-thread.txt)). This is the working reference for status/decisions; [`PRD.md`](PRD.md) is the detailed spec and milestone task checklist.

**Client:** Joel · **Timezone:** GMT (UK) · **Build:** Native Android & iOS (Flutter)

## Status

- Milestone 1 is **paid and active** — work can begin.
- Curriculum content was already developed by the client's consultant before dev started; this project is platform development, not curriculum authoring.
- Kickoff call held. Logo/brand assets received.

## Decision Log

- **Scope:** Client chose the *expanded* package: student auth/profiles, AI tutor with full curriculum RAG, homework OCR, basic gamification (XP/streaks), student dashboard, **plus** voice interaction, 3 months post-launch support, and SEO basics.
- **Web vs. native:** PWA was recommended (one codebase, instant deploy, push notifications, no store review delay) but the client chose **native Android + iOS only via Flutter**. PWA deferred, may be revisited later.
- **Devices:** ~80% Android / ~20% iPhone; ~80% tablets & phones — build mobile-first.
- **Voice:** English only at launch — curriculum is English-based, so voice engine is configured for English only (not a local language).
- **Vector DB:** Qdrant (decided after the PRD was written — supersedes the PRD's open "pgvector / Chroma / Pinecone" choice).
- **Curriculum source of truth:** Official NaCCA PDFs (three links below) **supersede** the consultant-provided xlsx/PDF packs. The consultant packs have templated per-grade content (same explanation, numbers scaled) and placeholder `VERIFY OFFICIAL CODE` indicator codes — usable to bootstrap the pipeline, but not exam-safe until replaced with verified official codes.
- **Payment:** Mobile Money via Telco API — separate, client-side track. Docs pending from Joel.
- **Store setup:** Apple Developer account to be started early (longest approval lead time). Android can ship via APK pre-Play-Store for testing. Joel handles his-side actions with developer guidance.

## Curriculum Hierarchy (authoritative model)

```
Grade → Subject → Strand → Sub-strand → Content Standard → Indicator → Official Indicator Code → Content
```

Official NaCCA sources (source of truth, supersedes consultant packs):
- Primary 4–6: https://nacca.gov.gh/learning-areas-subjects/new-standards-based-curriculum-2019/
- JHS 1–3: https://nacca.gov.gh/common-core-programme-ccp/
- SHS 1–3: https://nacca.gov.gh/secondary-education-curriculum/

## Milestone Structure (authoritative — weeks-based)

This is the real milestone plan; `PRD.md` §5 was rewritten to match it, with the engineering-level sub-tasks nested under each line.

| Milestone | Weeks | Focus |
|---|---|---|
| 1 | 1–2 | Flutter env (Android + iOS), design direction & app flow, student registration/login/profile data layer, dashboard scaffold + navigation, ingest & structure initial curriculum data for the AI pipeline |
| 2 | 3–5 | AI tutor ↔ curriculum via Qdrant (Socratic approach), homework OCR cross-referenced against curriculum, real-time voice (STT/TTS), model & cost review for production AI config |
| 3 | 6–7 | XP/streaks with backend persistence, rewards screen, full student dashboard, admin & telemetry dashboard |
| 4 | 8 | Native Android/iOS packaging, push notifications, store assets, cross-platform QA, launch & handover |

## Open Items / Blockers

- Mobile Money API docs — waiting on Joel, blocks payment work.
- Apple Developer account — Joel-side action, blocks store submission.
- Curriculum SME/accuracy sign-off — separate from code verification, needed before any "exam-safe" claim.
- Confirm which 1–2 subjects to prioritize for full ingestion beyond the initial test slice.
- Confirm SHS PDF links follow the same direct-link pattern as B4–B6/B7–B9 (not yet verified).
- Confirm whether leaderboards are in scope.
- Confirm which milestone owns Quizzes/Assessments, Assignments, Diagnostics + Remediation, and Progression Tracking — not mentioned by name in this weeks-based plan (see `PRD.md` §5 note).
