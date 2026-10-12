# AGENTS.md — Memorywell

> Source of truth: `docs/PLAN.md` (+ `docs/INITIAL_IDEA.md` for product context).
> Do not diverge from the plan without updating it first.

## Workflow

- Changes land via branch + PR into `main` (precedent: #1). Do not push to `main` directly.
- After checkout run `pre-commit install` once; hooks run on `git commit` and only touch staged files. Never `pre-commit run --all-files` except for a deliberate baseline.

## Build mode: learning-first, agent-guided

- The human builds by hand for AI-200 learning. The agent does **not** big-bang implement.
- Work is strictly sequential, starting at **Phase 1**. One phase at a time, no skipping ahead, no pre-implementation of future phases.
- Each phase follows this contract:
  1. Agent writes a per-phase directory `docs/phase-<n>/`: `_brief.md` (goal, AI-200 concepts, prerequisites, ordered-step index, basic file outline (paths + stubs, **not** full implementations), demo/review gate) plus one `step-x.md` per ordered step carrying that step's instructions, stub shapes/notes, and its manual verification checks.
  2. Human implements following the brief. Agent answers questions and unblocks on errors but does not take over.
  3. Agent sanity-checks what was built (human pastes/shows output) before issuing the next phase brief.

## Repo rules

- Planned layout (`docs/PLAN.md` § Repo layout): `infra/ api/ functions/ web/ docs/ scripts/`. Scaffold only what the current phase brief needs.
- Current tree is docs-only plus an empty untracked `api/` — `infra/ functions/ web/ scripts/` do not exist on `main` yet. Never assume code exists; check first.
- No pnpm workspace: when `web/` arrives (Phase 5), use a plain package manager inside `web/` only.
- Azure-first on the AI-200 stack; IaC is Bicep.
- Cheapest viable SKUs (Cosmos serverless, Postgres Burstable B1s, Redis Basic, Container Apps scale-to-zero, Functions consumption). Estimated ~$50–90/mo while running.
- `scripts/teardown.sh` must exist from early on; destroy resources between study sessions. The shared resource group (`rg-<base>-shared`, holds the cross-environment ACR) is kept by default — pass `--shared` to delete it too.
- Secrets never committed. Managed identities + Key Vault references everywhere. `.env` stays local/ignored.

## Formatting (enforced by `.pre-commit-config.yaml`)

- Python (`api/`, `functions/`): Ruff lint + format per `pyproject.toml` (100 cols, target py311 — no newer syntax).
- TS/JS/JSON/CSS/Markdown/YAML: Prettier per `.prettierrc.json` (`proseWrap: preserve`, so long docs lines are intentional).
- Bicep: `az bicep format` local hook (Space, indent 2). LF endings + final newline everywhere (EditorConfig, VS Code `formatOnSave`).

## Domain invariants (do not break)

- Circle of Care roles: N owners + Full Contributor + Observer + locked Recipient. Last-owner protection; `resolvedBy` audit on flag resolutions.
- Per-(chronicle, contributor) `displayAlias` + `promptCadence` (`none` | `special-occasions` | `monthly` | `weekly`, default `monthly`); memories snapshot `aliasAtWriteTime`.
- 3 event-driven agents only (Prompter, Curator, Guardian); coordination via Service Bus / Event Grid + Cosmos state — never direct calls.
- Single-shot conversation now; schema stays multi-turn-ready (`promptId`, `parentMemoryId`, `turnCount`, `conversationId`).

## Verification

- Per-phase manual checks + `pytest` per agent as defined in `docs/PLAN.md` § Verification.
- Final gate: scheduled check-in → voice-note reply → transcript in timeline → Guardian pass → review queue empty; plus alias-rename and flagged-content runs.
