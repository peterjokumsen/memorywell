# AGENTS.md — Memorywell

> Source of truth: `docs/PLAN.md` (+ `docs/INITIAL_IDEA.md` for product context).
> Do not diverge from the plan without updating it first.

## Workflow

- `main` is the integration branch for finished phases. Do not push to `main` directly.
- Each phase gets a long-lived `phase-<n>` branch cut from `main` (e.g. `phase-3`, `phase-4a`).
- Each step gets a `phase-<n>/step-<x>` branch cut from `phase-<n>` (e.g. `phase-3/step-4`). One step per branch, one PR from `phase-<n>/step-<x>` into `phase-<n>` — that PR is the review surface for the step. Do not commit directly to `phase-<n>`; it advances only by merging step PRs, and step branches are deleted after merge.
- A phase closes with a PR from `phase-<n>` into `main` once every step is signed off and the phase review gate passes.
- Docs/tooling changes that are not phase work use their own branch (e.g. `docs/<topic>`) and PR straight into `main`.
- After checkout run `pre-commit install` once; hooks run on `git commit` and only touch staged files. Never `pre-commit run --all-files` except for a deliberate baseline.
- `.github/workflows/ci.yml` is the merge gate (pre-commit, `pytest`, `az bicep build`, `bash -n`, `./scripts/check-logging.sh`) for PRs into `main` and `phase-*`. Every PR must be green; fix locally first (`pytest` in `api/`, `./scripts/validate-bicep.sh`, `./scripts/check-logging.sh`).

## Build mode: agent-implements, human-validates

- The agent implements the majority of the code. The human's job is to validate each step and learn from the what/why summary, not to type the implementation.
- Work stays strictly sequential in `docs/PLAN.md` phase order: one step at a time, no skipping ahead, no pre-implementation of later steps or phases.
- Each phase still gets `docs/phase-<n>/_brief.md` (goal, AI-200 concepts, prerequisites, ordered-step index, file outline, review gate) plus one `step-x.md` per step. Write the brief before code and update it if implementation forces a deviation.
- Each step is one handoff cycle:
  1. **Agent starts the step branch** `phase-<n>/step-<x>` from `phase-<n>`, implements the step, and runs the local gates (`pytest`, Ruff, `az bicep build`, `bash -n`, `./scripts/check-logging.sh`) until green.
  2. **Agent documents** it in `step-x.md`: a short `## What changed` / `## Why` summary (files touched, behaviour, decisions and trade-offs), a concise `## ELI5` that explains the step's core idea in plain language (one short paragraph or analogy, no jargon), and a `## Validate` section with exact commands and expected output.
  3. **Agent opens a PR** from `phase-<n>/step-<x>` into `phase-<n>` and stops; that PR is the review surface for the step.
  4. **Human validates** the PR — runs the checks, demos the behaviour, and may push adjustments to the same branch.
  5. **Agent reviews the human's adjustments** — the diff against the step's intent, repo conventions, and domain invariants — and reports findings: confirm, suggest a correction, or ask before changing anything the human wrote. The agent never silently reverts human edits, and pushes any fixes to the same branch.
  6. **Step closes** when the human merges the step PR into `phase-<n>`. Only then does the agent start the next step.
- Keep `## Validate` copy-pasteable: one command sequence where possible, so sign-off is a single run rather than a hunt.
- The agent never asks the human to run something it can run locally. Azure mutations stay human-run (provision, deploy, teardown) unless explicitly delegated; the agent authors the Bicep/scripts and validates them locally.
- Anything outside the current step's scope goes into `docs/PLAN.md` first as a follow-up step — no silent scope creep.
- This applies to in-flight work too: when an existing phase's step is picked up under the new mode, its step doc is updated to the handoff format above and its work moves to a `phase-<n>/step-<x>` branch; steps already on the phase branch stay there.

## Repo rules

- Planned layout (`docs/PLAN.md` § Repo layout): `infra/ api/ functions/ web/ docs/ scripts/`. Scaffold only what the current phase brief needs.
- Never assume the tree: check before planning or scaffolding (`git ls-tree --name-only origin/main`, `ls`). `infra/ api/ functions/ scripts/` exist; `web/` does not yet.
- `docs/EVENTS.md` is the central event catalog (event, emitter, consumer, purpose). Any new/renamed event, subscription, queue, or trigger updates it in the same PR.
- No pnpm workspace: when `web/` arrives (Phase 5), use a plain package manager inside `web/` only.
- Azure-first on the AI-200 stack; IaC is Bicep.
- Cheapest viable SKUs (Cosmos serverless, Postgres Burstable B1s, Redis Basic, Container Apps scale-to-zero, Functions Flex Consumption with no always-ready instances). Estimated ~$50–90/mo while running.
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

- Per-phase manual checks + `pytest` per agent as defined in `docs/PLAN.md` § Verification. The agent runs them before each handoff; the human re-runs the step's `## Validate` block at sign-off.
- Final gate: scheduled check-in → voice-note reply → transcript in timeline → Guardian pass → review queue empty; plus alias-rename and flagged-content runs.
