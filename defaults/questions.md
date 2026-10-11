# akg question catalog

<!--
Format, for every layer (akg → team → project):
- `## Title` identifies a question. Same title in a higher layer replaces it; `skip` as its body removes it.
- `key:` is where the answer is stored in `.claude/akg/config.yaml`. Required: a question without `key:` is ignored (with a one-line warning).
- Options are suggestions; rough free-text answers are fine.
- `multiple` (line after `key:`): checkboxes instead of a single choice, for independent options (max 4). The answer is a list; nothing checked = empty list.
  Use it for a list of independent actions or items; a question picking a level or one tool (strict/permissive, Jira/Linear) stays single choice.
- `per-project` (line after `key:`, or after `multiple`): the answer only makes sense for one project (its containers, its shortcuts, its folders).
  `/akg:source-init` neither asks nor stores it, so projects extending the source answer it themselves. Same for a follow-up key marked `per-project` (`(key: x.y, per-project)`, or `x.y per-project` in a list of keys).
- `→` lines are free-text instructions for Claude:
  - under an option: applied only when that option is chosen;
  - at the end of the question: applied whatever the answer.
  They can ask a follow-up question (with its own key), check something read-only (a command, an MCP server, a file),
  propose something (a line in CLAUDE.md, a plugin, a setting). They never install or modify anything by themselves.
Which questions are asked is set by `questions:` in config.yaml (a list of key prefixes, e.g. [workflow, tracker]).
Without it: `workflow`, `deps`, `env`, `arch`, `security`, `tracker` + every question defined in the team/project questions.md. The rest of this catalog is off by default.
- Options written as placeholders (`<detected …>`) are built from the project scan.
Every active question is asked. A known answer (team, project or detected) is offered first; "I don't know" is offered last (single choice only).
-->

## Project type
key: workflow.type
What kind of project is this? Its defaults apply to akg's own questions; a team or project question keeps its own recommendation.
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
When is a change done? Propose 2 lists built from the context and the detected commands.
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
- Run migrations (local database only)
  → CLAUDE.md: "You may run migrations on the local database only."
- Delete files
  → CLAUDE.md: "You may delete files that your change makes obsolete; list them in your summary."
  → Settings: allow `Bash(rm *)`.
→ For each unchecked action: CLAUDE.md "Ask before <action>"; settings: ask for its command — commit `Bash(git commit *)`, push `Bash(git push *)`, delete `Bash(rm *)`; migrations have no generic command.
→ Whatever the answer: settings: deny `Bash(git push --force *)` and `Bash(git push * main)` (use the detected default branch).

## Dependencies
key: deps.policy
Can Claude add dependencies?
- Ask first (recommended)
  → CLAUDE.md: "Never add a dependency without asking. Prefer the standard library and existing dependencies."
  → Settings: ask for the install commands of each detected package manager, with their common variants (npm: `Bash(npm install *)`, `Bash(npm i *)`, `Bash(npm add *)`; yarn/pnpm: `add`; pip: `install`; composer: `require`; go: `get`).
- Free, if justified
  → CLAUDE.md: "You may add a dependency when justified; say which and why in your summary."
- Forbidden
  → CLAUDE.md: "Never add dependencies."
  → Settings: deny the same install commands (and variants) of each detected package manager.

## Command environment
key: env.runtime
per-project
Where are the project commands (tests, lint, build) run?
- Inside a container (docker compose exec…) (recommended when a compose file defines services)
  → Detect the service names from the compose file; offer them as options, otherwise ask in one plain-text message (key: env.service, per-project).
  → CLAUDE.md: run the test, lint and build commands as `docker compose exec <service> <command>`; use these forms in the commands list and the Definition of Done. Not the dev server when compose already starts it (`command:` in the compose file).
  → Settings: allow the container forms of the test and lint commands; ask for `Bash(docker compose down -v *)` (deletes volumes, i.e. local data).
- On the host
- Dev container (VS Code / devcontainer.json) (recommended when `.devcontainer/` exists)
  → CLAUDE.md: Claude runs inside the dev container; use the commands as they are.
- Mixed
  → Ask in one plain-text message which commands run where; CLAUDE.md: one line per command.
→ Ask only if a container setup is detected (`Dockerfile`, `compose.yaml` / `docker-compose.yml`, `.devcontainer/`); otherwise skip it silently.
→ Pre-fill from how the README, Makefile or scripts run the commands (e.g. a `make test` target calling `docker compose exec`).

## Local environment
key: env.tools
multiple
per-project
Anything Claude should know to work on this project locally?
- <detected shortcut> (Detected)
- <detected project CLI> (Detected)
- <detected task runner> (Detected)
- Something to add
  → Ask in one plain-text message: CLIs, shortcuts, aliases and prerequisites (VPN, aws-vault, seed data…), and what each is for (key: env.notes, per-project).
→ The options are built from the scan: up to 3 detected items, excluding the test/lint/build/dev commands already confirmed (Makefile targets such as `make up` / `make shell`, project CLIs such as `bin/console`, `artisan`, `manage.py` — dev tooling, never the binary the project itself ships (the `bin` of `package.json`, a Go `main`) — task runners such as `just` or a Taskfile, infrastructure tools whose files are in the repo such as `terraform` (`*.tf`), `kubectl`/`helm` (manifests, charts), `pulumi`), each labelled "(Detected)" with its source, then "Something to add". Nothing detected → single choice "Nothing special (recommended)" / "Something to add".
→ If the commands run in a container (env.runtime): ask the same for inside the container (tools available only there, how to open a shell, which service).
→ Check read-only that the CLIs mentioned are on the PATH (or in the container image definition); report missing ones in one line.
→ Settings: for a detected tool with destructive commands, ask for them — `terraform apply/destroy`, `kubectl apply/delete`, `helm install/upgrade/uninstall`, `docker compose down -v`, `pulumi up/destroy` — even if nothing is checked (the tool is in the repo, so Claude may use it). Write these destructive-command rules in both forms, bare and with arguments (`Bash(terraform apply)` and `Bash(terraform apply *)`); other rules (install commands, push, rm) use the argument form only, so a bare `npm install` stays free. Read-only commands (`terraform plan`, `kubectl get`) stay free.
→ CLAUDE.md: a "## Local environment" section, one line per tool and when to use it; for a destructive tool, add "Never run <commands> without asking."

## Architecture
key: arch.style
per-project
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
  → Settings: deny `Read(**/.env*)` (any folder, for monorepos). Check that `.env*` is in `.gitignore`; if not (or no `.gitignore`), propose adding `.env*` followed by `!.env.example` (keep the committed example) as an extra file in the review step.
- Secret manager (Vault, AWS/GCP…)
  → Ask which one (key: security.manager): offer a detected value as option, otherwise ask in one plain-text message.
- CI variables only
→ CLAUDE.md: "Never write, print or commit secrets; use placeholders."

## Ticket tracker
key: tracker.tool
Where are tickets tracked?
- None (recommended)
- Jira
  → Ask the site URL, the project key and Cloud vs Data Center (keys: tracker.url, tracker.project per-project, tracker.hosting): offer detected values as options (URL from the README, key from commits like `SHOP-123`), otherwise ask in one plain-text message.
  → Check whether an Atlassian/Jira MCP server is configured (`claude mcp list`) or a `jira` CLI is on the PATH; if neither, suggest one (the Atlassian MCP server works with Cloud only).
  → CLAUDE.md: reference tickets as <PROJECT>-123 in branch names and commit messages.
- GitHub Issues
  → Detect the repository from `git remote -v` (key: tracker.project, per-project); ask in plain text only if there is no GitHub remote.
  → Check whether the `gh` CLI is on the PATH and authenticated (`gh auth status`); if not, suggest it.
  → CLAUDE.md: reference issues as #123 in commit messages; "Closes #123" in pull requests.
- Linear
  → Ask the team key (key: tracker.project, per-project): offer a detected value as option, otherwise ask in one plain-text message.
  → Check whether a Linear MCP server is configured (`claude mcp list`); if not, suggest it.
  → CLAUDE.md: reference issues by their identifier in branch names and commit messages.
→ Pre-fill from the scan: ticket ids in recent commits and branch names, tracker links in the README, `.github/ISSUE_TEMPLATE/`.
→ Any other tool (GitLab, Azure DevOps, Trello…), given through "Other": ask in one plain-text message its URL and how tickets are referenced (keys: tracker.url, tracker.project per-project); check whether its CLI is on the PATH (`glab`, `az`…).
→ If a tracker is chosen — CLAUDE.md (shared, so conditional: access is per developer): "When given a ticket id and you can access the tracker (MCP server or CLI), read the ticket before starting."
→ If a tracker is chosen: add it, its URL and project to the Project context.

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
→ If deployed: add the deployment target to the Project context.

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
  → Ask for the e2e command if none is detected (plain text, per-project).
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
