# akg — Claude Code setup plugin

Claude Code plugin that sets up Claude Code on a project from an optional team
config, by asking questions about the project, then keeps it in sync with the team.

## Language

- Everything in this repo (code, skills, docs, commit messages) is in **English**.
- Conversation with the maintainer happens in French.

## Commands

The plugin is named `akg`, so Claude Code exposes its skills as `/akg:<skill>`.

| Command | Purpose |
|---|---|
| `/akg:setup` | First run: link the team config, detect the stack, ask questions, propose config and plugins |
| `/akg:pull` | Pull team config updates into the project, without touching local overrides |
| `/akg:source-init` | Make this project the team source other projects `extends`: build its marketplace and package its plugins |

## Files

Same path and names in the project and in the team repo:

```
.claude/akg/
  config.yaml
  questions.md
  patterns/{common,backend,frontend}.md
```

### `config.yaml`

Claude Code never reads it; akg generates native files from it.

| Key | Content | Generates |
|---|---|---|
| `extends` | Team config: a single file (local path or HTTPS URL) or a project (local dir or git repo), with an optional `#<branch/tag/commit>` for git sources. Project side only. One value. | — |
| `synced` | Last synced team version: commit SHA (repo) or content hash (file). Project side only, committed. | — |
| `settings` | Raw fragment of Claude Code's `settings.json` (permissions, env, hooks…), deep-merged | `.claude/settings.json` |
| `marketplaces` | Plugin marketplaces to draw plugins from | `extraKnownMarketplaces` |
| `plugins.disabled` | Plugins refused for this project | — |
| `questions` | Key prefixes of the questions to ask (`[workflow, tracker, deploy]`). Default: `workflow`, `deps`, `env`, `arch`, `security`, `tracker` + team/project-defined questions | — |
| *question keys* | Answers, at the key each question declares (e.g. `workflow.tdd`, `deploy.target`) | `CLAUDE.md` |

The project file contains only `extends`, `synced` and overrides: a key present there is an override (including answers to keys the team does not set).

### `questions.md`

Questions asked by `/akg:setup`, in Markdown, interpreted by Claude (rough answers are fine).
- Same `##` title as a lower layer → replaces it. New title → added. Title followed by `skip` → removed.
- `→` lines are free-text instructions for Claude: under an option, applied when it is chosen; at the end of the question, applied whatever the answer. They can ask a follow-up question (with its key), run a **read-only** check (command on PATH, MCP configured, file present) and propose something (a `CLAUDE.md` line, a plugin, a setting). They never install or modify anything: they come from a team repo, i.e. a third party.
- Each question declares the `config.yaml` key its answer goes to (`key: deploy.target`). Base questions follow the same rule (`key: workflow.tdd`); `workflow` is not a special case. A question without `key:` is ignored, with a one-line warning (`akg: question "<Title>" ignored — no key`).
- akg ships a **catalog** (`defaults/questions.md`): on by default: `workflow.*` (project type, DoD, TDD, review, Claude autonomy), `deps.policy`, `env.runtime` (only when a container setup is detected), `env.tools`, `arch.style`, `security.secrets`, `tracker.tool`; off by default: `deploy`, `git.commits`, `git.branching`, `git.language`, `tests.levels`, `db.migrations`, `docs.policy`. `questions:` in `config.yaml` picks which to ask, by key prefix; the project list replaces the team list. No need to `skip` a question to turn it off.
- `multiple` (line after `key:`) turns a question into checkboxes for independent options (max 4, e.g. Claude autonomy, docs): the answer is a list, nothing checked is a valid answer, no "I don't know". A question picking a level or one tool stays single choice.
- A conditional question ("Ask only if …") whose condition is not met is skipped silently and stores nothing; `/akg:pull` asks it once the condition holds (e.g. a Dockerfile appears), if the question is active — on its next run with a team change; otherwise re-run `/akg:setup`.
- Options can be built from the scan when the question says so (e.g. Local environment: `<detected shortcut> (Detected)` placeholders, filled from the Makefile, project CLIs, task runners).
- A question whose answer sets defaults for others (Project type) is asked alone, first; those defaults apply to akg's catalog questions only — a team or project question keeps its own recommendation. Follow-up values for one tool are asked together: one click if all are detected, otherwise one plain-text message showing the detected ones. With more than 4 options, the ones the scan makes unlikely are dropped first (still reachable through "Other").
- **Every question is asked**, even when the answer is known. Options (single choice): the known answer first ("(Team)", "(Project)" or "(Detected)"), then the question's options, then **"I don't know"** (keeps the team value or the recommended option, as a default, not an override; with no team value, the recommended value is stored with a comment so pull does not ask again); "Other" for free text.

```markdown
## Deployment
key: deploy.target
Where is this project deployed?
- Kubernetes (recommended)
- Lambda
```

### `patterns/`

Code convention **templates** (`common`, `backend`, `frontend`). Claude adapts them to the answers and the detected stack to write `CLAUDE.md`; they are not copied verbatim. Fullstack / monorepo projects get one `CLAUDE.md` per sub-folder (`frontend/`, `api/`…), each using the matching template.
- Sub-project detection: a sub-folder with its own manifest (`package.json`, `pom.xml`, `go.mod`, `composer.json`…), at most two levels deep. Classified `frontend` if its dependencies include a front-end framework (React, Vue, Angular, Svelte…), else `backend`. The mapping is shown for confirmation/edit. `common` applies to the root `CLAUDE.md`.

## Design decisions

- **Three layers: akg → team → project.** The layer closest to the project wins, for every file (`config.yaml`, `questions.md`, `patterns/`). akg ships a question catalog and minimal templates.
- **The team config is optional.** Without `extends`, `/akg:setup` works the same; `/akg:pull` and the session hook do nothing.
- **Nothing is imposed.** Config, settings, marketplaces and plugins are always proposed and approved by the user.
- **Team repo = a standard Claude Code plugin marketplace** (`.claude-plugin/marketplace.json`) plus `.claude/akg/`. Skills, hooks, agents and MCP servers are distributed as regular plugins; akg does not reinvent distribution, and plugins stay usable without akg.
- **Plugins are enabled, not copied** (`enabledPlugins`). akg evaluates the `relevance` blocks of `marketplace.json` itself: a plugin with `relevance` is proposed only when its signals match the project; a plugin without `relevance` is proposed on every project. No marketplace → no plugin proposed. akg says why each plugin is proposed.
- **`relevance` at setup time uses fixed rules**, never free judgement: `manifestDeps` → regex on the project's manifests; `filesRead` → matching files exist in the repo; `cwd` → glob on the project path; `cli` → command name appears in detected commands; `hosts` → ignored.
- **Answer lists** (DoD, autonomy…) in the project `config.yaml` replace the team list as a whole; only `settings` arrays are concatenated.
- **Settings merge.** Deep merge into `.claude/settings.json`: objects key by key, arrays concatenated and deduplicated; a differing scalar is shown as a conflict. akg never removes anything. Settings derived from answers (`→ Settings:` lines) are not stored: they are recomputed from the answers at setup and pull.
- **Plugins from an external repo** must be installed once per developer; akg gives the exact install command when proposing them.
- **Stack and commands** (test, lint, build) are **detected, then always shown for confirmation or edit**. Prefer commands already declared in the project (`package.json` scripts, `Makefile` targets…); never invent elaborate ones.
- **Team cache** in `~/.cache/akg/`, refreshed on each `/akg:setup` and `/akg:pull`. Past team versions for pull diffs go to `~/.cache/akg/snapshots/<commit>` and are reused.
- **`/akg:pull`** never overwrites a local override without approval: it shows the conflict ("team says X, project says Y") and lets the user keep local, take team, or merge. Each non-conflicting change is also proposed (Apply / Keep current); declining a config value makes it an override; a declined list addition or template change is just not applied (`synced` moves on, so it is not proposed again). A new template convention that contradicts the existing code is flagged in one line.
- **Sync reminder.** A `SessionStart` hook gets the team's latest version (`git ls-remote` for a repo, download + hash for a remote file; ~2 s timeout) and compares it with `synced`. Silent when nothing changed or offline; otherwise one line: `akg: team config updated — /akg:pull`. Shown once per new team version (notification state per developer in `~/.cache/akg/`).
- **Branch.** `extends: <source>#<ref>` pins a branch, tag or commit (Claude Code's own `owner/repo#ref` syntax). Each ref has its own cache; the reminder watches that ref; the team marketplace gets the same `ref`. Ignored, with a warning, on a single file.
- **Remote single file** over HTTPS only, no auth in v1. Private team config → use a git repo (developer's git credentials).
- **Empty team repo:** nothing is proposed for now.
- **Making a project the team source.** `/akg:setup` step 1 offers a third option, "This project is the team source"; `/akg:source-init` does the same later on an already set-up project. The project becomes the team layer as is: other projects `extends` it (local dir or git repo). It gets no `extends` and no `synced`, and its `config.yaml` is not split: project-specific answers (`arch.style`, `env.runtime`, commands) are inherited too, harmless since every question is still asked downstream with the team value as first option.
- **Source plugins.** One question (checkboxes, pre-filled by the scan) picks the marketplace plugins: plugins already enabled (`enabledPlugins`, `claude plugin list`), referenced at their original source, never copied; local content (`.claude/skills/`, `.claude/agents/`, `.claude/commands/`, hooks) **moved** into `plugins/<name>/`, and the project enables its own plugin instead (one location, no duplicate); extra plugins (GitHub repo or URL) asked afterwards in plain text. A plugin from a local or private marketplace (path on this machine) cannot be shared: excluded with a one-line warning. Plugin names must not start with `claude-`.
- **Generated source files**, shown and approved like any other change: `.claude-plugin/marketplace.json` (chosen plugins, each with a `relevance` block inferred from the scan, e.g. `manifestDeps: ["react"]`, confirmed or removed by the developer; a plugin without `relevance` is proposed on every project, said in one line) and `plugins/<name>/`. No `questions.md` or `patterns/`: akg defaults apply until the team customizes them. Nothing outward: the developer commits and pushes, then gives the repo URL to teammates for their `extends`.
- **Scan first, ask last.** `/akg:setup` scans the project (manifests, README, docs, CI, tests, recent commits) before any question, pre-fills every answer it can infer (with its evidence), and shows **one** summary — stack, commands, layout, what it understood — to confirm or edit in free text. Every question is still asked, with the known answer as the first option: one click to confirm, or the developer goes further. Goal: minimal typing, full control.
- **"What I understood" recap.** Part of that summary: purpose, key folders, inferred architecture, integrations; the developer adds or corrects points. The result is the `## Project context` section of `CLAUDE.md`; it belongs to the developer, who edits it directly later. `/akg:pull` never touches it.
- **Single project**: the root is classified `frontend`/`backend` like a sub-project, and its `CLAUDE.md` merges `common` with that template.
- **No dependency on the built-in `/init`.** `/akg:setup` does its own repo analysis and writes `CLAUDE.md`.

## Skill writing guidelines

- Keep output short. The target user is a senior dev who dislikes ceremony.
- Talk in the user's language: the catalog is in English, Claude translates questions and options; generated files stay in English unless the Language answer says otherwise.
- Explain domain jargon (devops, secops…) in one sentence when it appears.
- Ask questions with the `AskUserQuestion` tool (selectable options, one tab per question, up to 4 per call), 2–4 options, recommended one first. Every option is a real answer: a free value (URL, path) is asked afterwards in one short plain-text message, never via an option meaning "type it in Other".
- Never write files in the target project without showing the change and getting approval.
- `allowed-tools` pre-approves only the scripts and the read-only commands the scan and checks use (`git log`, `git remote`, `which`, `claude mcp list`, `gh auth status`, `diff` for pull…), so setup runs without approval prompts.
- Destructive commands of detected tools (`terraform apply/destroy`, `kubectl delete`…) always get an `ask` rule; install commands cover their common variants (`npm i`, `npm add`); an answer may propose an extra file (`.gitignore` with `.env*` and `!.env.example`), reviewed like the others. Destructive-command rules use both forms, bare and with arguments (`Bash(terraform apply)`, `Bash(terraform apply *)`); other rules use the argument form only, so a bare `npm install` stays free.
- A question-level `→` line that only makes sense for some answers says so ("If a tracker is chosen: …").

## Repository layout

The repo is both the plugin and its own marketplace (plugin name `akg`; names must not start with `claude-`).

```
.claude-plugin/
  plugin.json
  marketplace.json     # single entry, "source": "./"
skills/
  setup/SKILL.md
  pull/SKILL.md
  source-init/SKILL.md
hooks/hooks.json
scripts/fetch.sh       # resolve a team/marketplace source to a local path + version
scripts/snapshot.sh    # team config at a past version, for pull diffs
scripts/check-team.sh  # SessionStart hook: one-line reminder on new team version
references/rules.md    # layers, merge, relevance rules shared by setup and pull
defaults/              # akg base layer
  questions.md
  patterns/{common,backend,frontend}.md
fixtures/              # sandbox projects for manual testing
  no-team/
  extends-local-team/
  monorepo/
  team/                # local team repo (marketplace + .claude/akg/)
  try.sh               # copy fixtures to a temp dir, print the command to run
README.md
```

## Testing

- Load: `claude --plugin-dir <repo>`; reload after edits: `/reload-plugins`; check: `claude plugin validate .`.
- Replay each user flow by hand on `fixtures/`. `claude plugin eval` later.
