# AI usage note

Politiface's statement of what AI systems do and do not touch. Written for
the HECVAT 4 AI governance section and for any institutional reviewer.
Last updated: July 4, 2026.

## Where AI is used

1. **Question drafting (content pipeline, not the app).** Large language
   models (Anthropic Claude) assist in DRAFTING exam-practice questions and
   explanations from primary public sources (the Constitution, founding
   documents, Federal Register, official state publications). Every
   AI-drafted question then goes through the same gate as human-written
   content: a human editorial review, a working primary-source citation,
   and a `draft -> reviewed -> published` status flow. Nothing AI-drafted
   is shown to students before a human publishes it.
2. **Engineering assistance.** AI coding tools help write the open-source
   codebase. All code is human-reviewed in pull requests and publicly
   auditable (MIT license).

## Where AI is not used

- **No student data ever passes through an AI system.** The learning
  engine (FSRS-4.5) is deterministic arithmetic, not a model. Readiness
  scores are rolling accuracy computations in SQL and Dart.
- **No AI at runtime.** The shipped app makes no calls to any LLM or
  inference API. There is no chatbot, no generated feedback, no profiling.
- **No AI decision-making about students.** Nothing AI-derived affects
  grades, access, pricing, or any student-visible outcome.

## Controls

- Content provenance is tracked per question (`author`, `review_status`,
  citation required by schema and CI).
- The content pipeline rejects unsourced or uncited material automatically
  (`scripts/ingest_content.py`).
- This note is reviewed when any new AI use is introduced.
