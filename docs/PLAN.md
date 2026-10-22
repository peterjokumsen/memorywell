# Memorywell - Plan

An AI-200 practice project: a "Circle of Care" time-capsule web app (see
`INITIAL_IDEA.md`). Each household holds per-child chronicles; owners (both
parents), contributors (relatives), and observers add text/photo/voice-note
moments the child unlocks later. Three lightweight event-driven agents run the
loop: Prompter (asks), Curator (stores), Guardian (flags for owner review).
The backend is built entirely on the AI-200 (Developing AI Cloud Solutions
on Azure) stack, which remains the core learning goal.

> **Status:** Planning complete. Build not started.
> **Target repo for the build:** `~/repos/memorywell` (this repo is the planning space).
> **Build mode: learning-first, agent-guided.** Each phase is done mostly by hand
> for AI-200 learning. The AI agent does NOT big-bang implement; per phase it
> provides a short documentation pack (what/why, instructional steps, file
> outline), then reviews what was built before the next phase starts.

---

## Decisions

| Topic            | Decision                                                                                                                                                                             |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Interaction mode | Text/photo/voice-note based (messaging style + Drop Zone)                                                                                                                            |
| Cloud            | Azure-first - real resources on the AI-200 stack                                                                                                                                     |
| Scope            | Family app now, designed for productization (auth, multi-tenant); Circle of Care from `INITIAL_IDEA.md`                                                                              |
| Cadence          | Contributor-chosen per chronicle: none / special-occasions / monthly / weekly (default: monthly); plus on-demand + milestone nudges if cadence allows                                |
| Agent replies    | Text only (contributors reply with text, photo, or voice notes)                                                                                                                      |
| Agents           | 3 event-driven agents: Prompter/Nudger, Curator/Memory Keeper, Guardian/Reviewer (auto-apply after Guardian pass)                                                                    |
| Conversation     | Single-shot now; schema is multi-turn-ready (`promptId`, `parentMemoryId`, `turnCount`, `conversationId`)                                                                            |
| Roles            | N owners (both parents) + Full Contributor + Observer + locked Recipient (child); Owner = Contributor permissions + curate/review                                                    |
| Aliases          | Owner sets canonical name+relation on invite; contributor picks per-chronicle `displayAlias` (e.g. Gaga/Granny); natural-language rename ("you call me Granny") triggers update flow |
| IaC              | Bicep                                                                                                                                                                                |
| Subscription     | Azure subscription ready to use                                                                                                                                                      |

---

## Architecture -> AI-200 domain mapping

### 1. Containerized solutions (20-25%)

- Python **FastAPI** API + worker, containerized
- Images built/stored via **Azure Container Registry**, built with **ACR Tasks**
- Deployed to **Azure Container Apps**: environment configuration, **revision
  management**, **KEDA** event-driven scaling on Service Bus queue depth
- Static **web frontend on Azure App Service** (env vars + Key Vault references)
- **AKS: skipped** - high cost, low value for a family app; revisit only as a
  standalone study exercise

### 2. Data management services (25-30%)

- **Azure Cosmos DB for NoSQL**: households, chronicles (per child), contributors,
  invites, prompts, memories, transcripts, flags, aliasHistory
  - SDK queries, tuned **indexing policy**, chosen **consistency level**
  - **Vector index** for semantic search over raw messages
  - **Change feed processor** (Function change-feed trigger) -> generates embeddings
    and refreshes caches on new/updated items
  - Membership rows carry `role` + `chronicleIds`; multiple `role=owner` rows allowed;
    last-owner protection (cannot demote/remove final owner); flag resolutions store
    `resolvedBy` audit
  - Contributor record split: owner-managed (`contact`, `relation`, `status`) +
    contributor-managed per-chronicle `displayAlias` map and per-chronicle
    `promptCadence` map (`none` | `special-occasions` | `monthly` | `weekly`,
    default `monthly`); each memory snapshots
    `contributorId` + `aliasAtWriteTime` plus `promptId`, `parentMemoryId`,
    `turnCount`, `conversationId` for future multi-turn
- **Azure Database for PostgreSQL (pgvector)**: primary RAG memory store - the Prompter
  retrieves relevant past answers with **metadata filters** (chronicle/daughter,
  contributor, topic, date range) when formulating questions; connection
  pooling/optimization configured
- **Azure Managed Redis**:
  - TTL **caching** of hot memories/session state + contributor alias lookups with
    explicit **invalidation** (alias updates invalidate)
  - **Vector index** for fast recent-similarity lookups
- **Blob Storage**: voice-note audio + compressed photos (the keepsakes themselves);
  lifecycle tiering (hot/cool/archive), mono AAC/MP3 for voice, compressed JPEG for
  photos; open formats (JPEG/MP3/JSON) + JSON export for longevity

### 3. Connect to and consume Azure services (20-25%)

- **Azure Service Bus**
  - Queue for voice-note transcription jobs
  - **Topic + subscriptions** fan-out for `memory.recorded` (embedding sub,
    digest sub, guardian sub) plus `alias.requested` / `alias.updated` and
    `memory.flagged`
  - **Dead-letter queue** handling with a monitoring/resubmit path (includes failed
    classifications/extractions)
- **Azure Event Grid**: custom events (`checkin.due`, `voice.received`,
  `memory.archived`, `memory.recorded`, `memory.flagged`, `alias.requested`,
  `alias.updated`) with **filters**, retry policies, routing to Functions
- **Azure Functions**: **triggers and bindings** throughout
  - Timer trigger: daily cadence sweep per (chronicle, contributor) — weekly if 7d
    elapsed, monthly if 30d elapsed, special-occasions only on calendar/milestone
    events, none skips all proactive prompts (Empty-Wall nudges included)
  - Service Bus trigger: transcription worker + Guardian reviewer
    (classification/validation)
  - Cosmos change feed trigger: embedding generation
  - HTTP trigger: webhook endpoint + magic-link invite claim
- **Azure OpenAI (Foundry)**: persona chat completions (Prompter), speech-to-text
  for voice notes, embeddings (Curator), plus lightweight classification /
  structured-output extraction (Curator alias-intent + Guardian safety/quality
  scoring); thresholds in App Configuration

### 4. Secure, monitor, troubleshoot (20-25%)

- **Managed identities** for service-to-service auth everywhere
- **Azure Key Vault**: secrets (rotation via Bicep/script); Key Vault references
  in Container Apps/App Service
- **Azure App Configuration**: persona definitions, default check-in cadence +
  special-occasion calendar (birthdays, holidays, owner-defined milestones),
  Guardian thresholds, feature flags (including multi-turn enablement flag, off
  for now)
- **OpenTelemetry SDKs** (Python) across API + Functions -> Azure Monitor /
  Log Analytics
- **KQL queries** for latency, failure rates, DLQ depth, flag rate - checked into `docs/`
  as a workbook

---

## App experience

- **Circle of Care**: Owner (parent) curates each child's chronicle, invites
  contributors via frictionless magic links (WhatsApp/iMessage -> Drop Zone, no
  heavyweight account); roles are Owner / Full Contributor / Observer / locked
  Recipient (child unlocks later). Any owner may act; all flag resolutions and
  alias changes are audit-logged.
- **Aliases**: owner sets canonical name + relation on invite (e.g. maternal
  grandmother); contributor picks per-chronicle `displayAlias` (e.g. Gaga for one
  daughter). Timeline and Contributor Threads show the alias snapshot; unique per
  chronicle, fallback to relation if unset, owner can override.
- **Agent 1 - Prompter/Nudger (outbound)**: cadence-aware scheduled check-ins,
  milestone/special-occasion nudges, and single-shot detail follow-ups as text-only
  question cards in each chronicle's persona, grounded with retrieved memories for
  continuity. Always addresses the contributor by current alias (`Hi Granny, ...`).
  Triggered by timer sweep (with per-contributor cadence filter) and `checkin.due` /
  milestone events. `none` suppresses proactive prompts but still allows one
  reactive detail follow-up to the contributor's own submission.
- **Agent 2 - Curator/Memory Keeper (inbound)**: consumes text/photo/voice
  submissions, extracts metadata (chronicle, contributor, topic, date, milestone
  tag), writes the canonical memory + embedding, invalidates caches, emits
  `memory.recorded`. Snapshots alias at write time. Also runs alias-intent
  extraction (`aliasChangeRequested`, `requestedAlias`) on every submission.
- **Agent 3 - Guardian/Reviewer (flagging)**: subscribes to `memory.recorded`;
  safety/sensitivity + quality/duplicate scoring; writes
  `flag {reason, score, status}` and emits `memory.flagged` for the Owner review
  queue. Human-in-loop: owners approve/edit/hide/dismiss; Guardian runs on create
  only, low-cost model. Also validates alias requests (uniqueness,
  appropriateness, own-alias-only); pass -> auto-apply + `alias.updated` event,
  fail -> flag for owner. Next Prompter turn confirms (`Got it, Granny — ...`).
  Agents never call each other directly; all coordination is via Service Bus /
  Event Grid + Cosmos state.
- **Check-ins**: each (chronicle, contributor) pair has a contributor-chosen cadence
  (`none` / `special-occasions` / `monthly` / `weekly`, default `monthly`) set at
  invite claim and changeable in settings; prompts arrive as question cards,
  contributors reply anytime
- **Voice notes**: recorded in-browser (MediaRecorder) -> Blob -> Service Bus ->
  transcribed -> transcript + audio linked in the timeline
- **Photos**: compressed upload -> Blob with tiering; linked in the timeline
- **Timeline/archive view**: per-chronicle chronological feed with Contributor
  Threads and Milestone Chapters ("Baby Years", etc.), filterable, playable
  audio - the "listen when older" surface. Owners see all chronicles in the
  household plus the review queue; others see scoped views.
- **Auth (productization-ready)**: App Service Easy Auth with Microsoft accounts +
  household membership table in Cosmos DB; magic-link invite-claim flow; second
  household later

---

## Repo layout (`~/repos/memorywell`)

```plaintext
memorywell/
  infra/        Bicep: shared.bicep (shared RG: ACR, future appconfig) +
                modules acr, containerapps, cosmos, postgres, redis,
                servicebus, eventgrid, functions, keyvault, appconfig, monitor
  api/          FastAPI container: prompter.py, curator.py, guardian.py, shared
                rag.py, conversations, persona, voice/photo upload
  functions/    Python Functions (timer check-ins/nudges, SB transcription worker,
                SB guardian reviewer, change feed embeddings, HTTP invite claim, DLQ)
  web/          Frontend (Vite + React: Drop Zone, timeline, owner review queue)
  docs/         architecture.md, AI-200 skills-to-components matrix, KQL queries
  scripts/      provision-env.sh, teardown.sh, seed
```

---

## Build phases

**Phase execution contract (applies to every phase below):**

1. Agent writes a phase brief as `docs/phase-<n>/_brief.md`: goal, AI-200
   concepts, prerequisites, the ordered-step index, basic file outline (paths +
   stubs, not full implementations), and what to demo before proceeding. Each
   ordered step gets its own `docs/phase-<n>/step-x.md` with that step's
   instructions, stub shapes/notes, and manual verification checks.
2. Human builds it by hand following the brief (agent answers questions,
   unblocks on errors, but does not take over implementation).
3. Brief closes with a review gate: what to show / paste back so the agent can
   sanity-check before the next phase brief is issued.

| #   | Phase                | Contents                                                                                                                                                                                                                                       |
| --- | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Foundation           | Bicep: shared resource group (ACR shared across envs; AppConfig deferred for cost/value — returns with Phase 4 keys) + env resource group with Log Analytics, Key Vault; skeleton API deployed to Container Apps (revision management day one) |
| 2   | Data layer           | Cosmos DB (chronicles/contributors/invites/memories/flags, indexing policy + vector), Postgres/pgvector, Managed Redis; multi-owner + alias fields; seed script                                                                                |
| 3   | Messaging            | Service Bus queue/topic/DLQ (`memory.recorded`, `memory.flagged`, `alias.*`), Event Grid custom events, Functions (timer + SB + change feed + HTTP claim)                                                                                      |
| 4a  | Prompter             | Persona system prompts, RAG question generation with alias injection + cadence filter, single-shot follow-ups; multi-turn fields written but gated off                                                                                         |
| 4b  | Curator              | Metadata extraction + structured alias-intent output, canonical write + embedding wiring, conversation API                                                                                                                                     |
| 4c  | Guardian             | Classification/scoring, flag write + `memory.flagged`, alias validation + auto-apply path                                                                                                                                                      |
| 5   | Frontend             | Drop Zone + invite claim + alias picker + cadence picker, chat UI, voice/photo capture, timeline with threads/chapters, owner review queue, Easy Auth                                                                                          |
| 6   | Voice/photo pipeline | Blob (tiering, compressed formats) -> Service Bus -> STT -> transcript back to Cosmos                                                                                                                                                          |
| 7   | Observability        | OpenTelemetry end-to-end, KQL workbook (incl. flag rate), DLQ alert                                                                                                                                                                            |
| 8   | Productization       | Multi-household invites, milestone grouping polish, digest generation, JSON export / physical-book stub; freemium noted as future, out of scope                                                                                                |

**Build starts at Phase 1** (full plan, sequential, one brief at a time — no
skipping ahead, no agent pre-implementation).

---

## Cost & safety

- Cheapest viable SKUs: Cosmos serverless, Postgres Burstable B1s, Redis Basic,
  Container Apps scale-to-zero, Functions consumption
- Estimated **~$50-90/month** while running
- `scripts/teardown.sh` destroys everything between study sessions
- Secrets never committed to the repo

---

## Verification

- `pytest` per agent + Functions fixtures: Prompter grounding/no-repeat + alias
  rendering + cadence filter (none/special/monthly/weekly due logic); Curator metadata + embedding write + idempotency; Guardian flag
  precision/recall spot-check; alias flow ("you call me Granny" -> pending ->
  Guardian pass -> applied -> next prompt uses Granny; conflict -> flagged)
- Per-phase manual checks (send message -> see Service Bus message -> empty DLQ ->
  see trace in Log Analytics)
- Final end-to-end run: scheduled check-in -> voice-note reply -> transcript appears
  in the timeline -> Guardian pass with no flag -> owner review queue empty;
  plus alias-rename run and a flagged-content run

---

## Name candidates (for reference)

1. **Memorywell** _(chosen)_ - drop memories in, draw them up later; neutral for
   multi-household productization
2. **Little Voices** _(former)_ - the daughters' voices (questions) now, their
   voices (answers) saved for later
3. **Dear Future Us**
4. **Timekeepers**
5. **Pocket Daughters**
6. **Grow Log**
