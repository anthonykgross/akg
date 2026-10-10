# akg question catalog

<!--
Format, for every layer (akg → team → project):
- `## Title` identifies a question. Same title in a higher layer replaces it; `skip` as its body removes it.
- `key:` is where the answer is stored in `.claude/akg/config.yaml`. Required: a question without `key:` is ignored (with a one-line warning).
- Options are suggestions; rough free-text answers are fine.
- `multiple` (line after `key:`): checkboxes instead of a single choice, for independent options (max 4). The answer is a list; nothing checked = empty list.
- `→` lines are free-text instructions for Claude:
  - under an option: applied only when that option is chosen;
  - at the end of the question: applied whatever the answer.
  They can ask a follow-up question (with its own key), check something read-only (a command, an MCP server, a file),
  propose something (a line in CLAUDE.md, a plugin, a setting). They never install or modify anything by themselves.
Which questions are asked is set by `questions:` in config.yaml (a list of key prefixes, e.g. [workflow, tracker]).
Without it: `workflow`, `arch`, `security` + every question defined in the team/project questions.md. The rest of this catalog is off by default.
Every active question is asked. A known answer (team, project or detected) is offered first; "I don't know" is always offered last.
-->

## Project context
key: workflow.context
What kind of project is this?
- Product in production (recommended)
  → Defaults for the next questions: full DoD, TDD, standard review.
- POC / prototype
  → Defaults for the next questions: DoD "runs locally", no TDD, light review.
- Library
  → Defaults: TDD, strict review. CLAUDE.md: public API changes must stay backward compatible and be documented.
- Internal tool
  → Defaults: tests on the core logic only, standard review.

## Definition of Done
key: workflow.dod
When is a change done? Propose 2–3 lists built from the context and the detected commands.
→ CLAUDE.md: the checklist Claude must meet before saying a task is finished, with the real commands.

## TDD
key: workflow.tdd
Write the tests before the code?
- Yes (recommended for a product or a library)
  → CLAUDE.md: write a failing test first, then the code, then refactor.
- No (recommended for a POC)
  → CLAUDE.md: add or update tests for the changed behaviour before finishing.

## Review level
key: workflow.review
How thorough should Claude's self-review be before handing over?
- Standard (recommended)
  → CLAUDE.md: re-read the diff, run tests and lint before handing over.
- Light
  → CLAUDE.md: run the tests before handing over.
- Strict
  → CLAUDE.md: standard review, plus a pass on edge cases, security and performance.

## Claude autonomy
key: workflow.autonomy
multiple
What can Claude do without asking first? Editing files and running tests/lint is always allowed.
- Commit on feature branches
  → CLAUDE.md: "Commit freely on feature branches, never on the default branch."
  → Settings: allow `Bash(git commit *)`.
- Push feature branches
  → CLAUDE.md: "Push feature branches freely, never the default branch."
  → Settings: allow `Bash(git push *)`.
- Add dependencies
  → CLAUDE.md: "You may add a dependency when justified; say which and why in your summary."
  → Settings: allow the install command of the detected package manager (e.g. `Bash(npm install *)`).
- Run migrations
  → CLAUDE.md: "You may run migrations on the local database only."
→ For each unchecked action: CLAUDE.md "Ask before <action>"; settings: ask for its command.
→ Whatever the answer: CLAUDE.md "Ask before deleting files. Prefer the standard library and existing dependencies." Settings: deny `Bash(git push --force *)` and `Bash(git push * main)` (use the detected default branch).

## Architecture
key: arch.style
How is the code organised?
- Feature folders (recommended)
- Hexagonal / DDD
- Layered (MVC, controllers/services/repositories)
→ Pre-fill from the folder structure, with evidence.
→ CLAUDE.md: one line saying where new code goes, with the real folder names.

## Secrets
key: security.secrets
Where do secrets live?
- .env files, not committed (recommended)
  → Settings: deny `Read(.env*)`. Check that `.env` is in `.gitignore`; report in one line.
- Secret manager (Vault, AWS/GCP…)
  → Ask which one (key: security.manager): offer a detected value as option, otherwise ask in one plain-text message.
- CI variables only
→ CLAUDE.md: "Never write, print or commit secrets; use placeholders."

## Ticket tracker
key: tracker.tool
Do you use a ticket tracker?
- None (recommended)
- Jira
  → Ask its URL and the project key (keys: tracker.url, tracker.project): offer detected values as options, otherwise ask in one plain-text message.
  → Check whether an Atlassian/Jira MCP server is configured (`claude mcp list`) or a `jira` CLI is on the PATH; if neither, suggest one.
  → CLAUDE.md: reference tickets as <PROJECT>-123 in branch names and commit messages.
- Linear
  → Ask the team key (key: tracker.project): offer a detected value as option, otherwise ask in one plain-text message.
  → Check whether a Linear MCP server is configured (`claude mcp list`); if not, suggest it.
  → CLAUDE.md: reference issues by their identifier in branch names and commit messages.
- GitHub Issues
  → Check whether the `gh` CLI is on the PATH and authenticated (`gh auth status`); if not, suggest it.
  → CLAUDE.md: reference issues as #123 in commit messages.
→ Add the tracker (and URL if any) to the Project context.

## Deployment
key: deploy.target
Where is this project deployed?
- None / not deployed (recommended)
- Containers (Docker, Kubernetes)
  → Check whether `docker` / `kubectl` are on the PATH; mention what is missing.
  → CLAUDE.md: never change deployment manifests without saying so explicitly.
- Serverless (Lambda, Vercel, Netlify, Supabase edge functions…)
  → CLAUDE.md: keep functions small; mind cold starts and timeouts.
- Platform / VM (Heroku, Fly, bare servers…)
→ Add the deployment target to the Project context.

## Commit convention
key: git.commits
How are commit messages written?
- Conventional Commits (feat:, fix:…) (recommended)
  → CLAUDE.md: write commit messages following Conventional Commits.
- Free form
  → CLAUDE.md: match the style of recent commits.
→ Detect from the last commits before proposing; a detected style is the known answer.

## Test levels
key: tests.levels
Which tests do you write?
- Unit + integration (recommended)
- Unit only
- Unit + integration + e2e
  → Ask for the e2e command if none is detected (plain text).
→ CLAUDE.md: which test level to write for which change, with the detected test folders.

## Branching
key: git.branching
How do you branch?
- GitHub flow: feature branches → main (recommended)
- Trunk-based
- Git flow: develop / release / main
→ Detect branch names from `git branch -a` before proposing.
→ CLAUDE.md: branch naming and the target branch of pull requests.

## Database migrations
key: db.migrations
How are database migrations handled?
- Migration tool; never edit an applied migration (recommended)
  → Pre-fill the tool and folder from the scan. CLAUDE.md: the command to create a migration; never edit an applied one.
- No migrations / schema-less
→ Ask only if a database is detected (driver, ORM, migrations folder); otherwise skip it silently.

## Language
key: git.language
Language for code, comments and commits?
- English everywhere (recommended)
- English code; local language for comments and commits
  → Ask which language if it is not obvious from the recent commits.
→ CLAUDE.md: one line with the choice.

## Docs to maintain
key: docs.policy
multiple
Which docs must stay up to date?
- README (recommended)
- ADRs
  → Detect the ADR folder (`docs/adr`, `adr/`). CLAUDE.md: "Write an ADR for every architecture decision."
- CHANGELOG
  → CLAUDE.md: "Update CHANGELOG.md for every user-facing change."
→ Add the checked docs to the Definition of Done.
