# memorywell

Circle of Care time-capsule web app — AI-200 practice project. Each household holds per-child chronicles; owners, contributors, and observers add text/photo/voice-note moments the child unlocks later.

> **Status:** Phases 1–2 merged; Phase 3 (messaging) in progress.

- Plan: `docs/PLAN.md` (source of truth) + `docs/INITIAL_IDEA.md` (product context)
- Agent rules: `AGENTS.md` (per-step branch → PR into `phase-x` → what/why + validation checks → human validates and adjusts → agent reviews → merge, then `phase-x` → `main`)
- CI: `.github/workflows/ci.yml` (pre-commit, pytest, bicep build, shell syntax) — required to merge
- CI nightly teardown: `docs/CI_TEARDOWN.md` (setup for `.github/workflows/teardown.yml`)
