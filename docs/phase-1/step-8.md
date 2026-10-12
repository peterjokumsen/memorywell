# Phase 1 · Step 8 — `.env` hygiene

**`.env` hygiene.** Local-only `.env` (already git-ignored) holds
subscription ID, RG name, registry name. Nothing secret committed.

## Verify

- [x] `git status --short` shows no `.env`, no secrets, no `functions/`/`web/`
      (`.python-version` now git-ignored as local toolchain hint).
      `git log` paste waived — owner confirms log output is just commit
      history. Self-check before commit: `git status --short` lists only
      intended files. Still to do: remove untracked `deploy-log` at repo
      root (verbose deploy output, do not commit).
