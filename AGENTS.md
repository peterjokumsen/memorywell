# AI Agent Guidelines

## 1. Deep Understanding Before Code Modifications

Before making, proposing, or editing any code in this repository:

- **Investigate First**: Read and analyze relevant existing files, context, imports, and dependencies before generating or modifying code.
- **Non-default branch**: All changes must be made on a non-default branch; never commit directly to the default branch (e.g., `main`). Create a feature/fix branch first.
- **Trace Impact**: Understand the call stack, data flow, and side effects across the project to ensure changes do not break adjacent functionality.
- **Formulate a Plan**: Define a concise step-by-step plan of the required changes and confirm the root cause or target behavior prior to implementation.
- **Minimize Unnecessary Edits**: Do not refactor unrelated files or make speculative edits outside the scope of the immediate task.
- **Document everything without duplication**: All changes should have related documentation to describe the change, if nothing exists then it should be created.
- **Clean architecture**: Shoul apply SOLID principles for all changes, especially open-close and liskov.

## 3. Documented Phases (Automatic Implementation)

When a phase and its steps are documented (`docs/phase-<n>/_brief.md` plus
`docs/phase-<n>/step-x.md`), the agent implements the entire phase
automatically on a single branch named `phase-<n>-<brief-description>`: implement
all steps, run the local gates, record the `## What changed` / `## Why` /
`## ELI5` / `## Validate` sections, and open one PR for the whole phase. The
agent never merges; the human merges.

- All work happens on the `phase-<n>-<brief-description>` branch; never commit
  directly to the default branch and do not use per-step branches/PRs.
- Automatic implementation applies only to already-documented phases; do not
  skip undocumented phases or pre-implement later ones.
- The agent never silently reverts human edits pushed to the branch.

## 2. Semantic Commit Conventions

All commit messages generated or suggested must adhere strictly to the **Conventional Commits** standard.

### Commit Format

`<type>(<optional-scope>): <short imperative description>`

### Commit Types

- `feat`: A new feature for the user or codebase
- `fix`: A bug fix
- `docs`: Documentation-only changes
- `style`: Formatting, missing semi-colons, code style changes (no logic impact)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Maintenance tasks, dependency updates, or build configuration changes

### Rules

- Keep commit titles in the imperative, present tense ("add user auth" not "added user auth").
- Keep the title concise (50 characters or less preferred, 72 max).
- Include scope in parentheses when changes are isolated to a specific module or component (e.g., `feat(api): add user endpoint`).
