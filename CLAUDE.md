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
| `/akg:team` | Show the team's `team.md` (onboarding, tools to install, rules) |
| `/akg:source-init` | Create a team source in an empty folder: ask the team conventions and stacks, build its marketplace (installed, official and copied plugins) |

## Files

Same path and names in the project and in the team repo:

```
.claude/akg/
  config.yaml
  questions.md
  patterns/{common,backend,frontend}.md
  team.md          # team side only
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
- `per-project` (line after `key:`/`multiple`, or `(key: x.y, per-project)` on a follow-up) marks an answer that only makes sense for one project: `/akg:source-init` neither asks nor stores it (a source has no project). Catalog: `env.runtime`, `env.tools`, `arch.style`, and the follow-ups `env.service`, `env.notes`, `tracker.project`, the e2e command.
- `multiple` (line after `key:`) lets several independent options be picked (e.g. Claude autonomy, docs): the answer is a list, "none" is a valid answer. A question picking a level or one tool stays single choice.
- A conditional question ("Ask only if …") whose condition is not met is skipped silently and stores nothing; `/akg:pull` asks it once the condition holds (e.g. a Dockerfile appears), if the question is active — on its next run with a team change; otherwise re-run `/akg:setup`.
- Options can be built from the scan when the question says so (e.g. Local environment: `<detected shortcut> (Detected)` placeholders, filled from the Makefile, project CLIs, task runners).
- A question whose answer sets defaults for others (Project type) is asked alone, first; those defaults apply to akg's catalog questions only — a team or project question keeps its own recommendation. Follow-up values for one tool are asked together, right after their parent, the detected ones as the guess.
- **Every question is asked**, even when the answer is known, as an **interview** (after addyosmani/agent-skills' `interview-me`), in plain text, never `AskUserQuestion`: numbered answers, **1 = Claude's guess** with its evidence (team, project, scan) or else the recommended option, then the question's other options, no limit. Reply "ok", a number, or free text. One question per message when the guess is only a recommendation (and Project type, first); up to 3 per message (A, B, C → "B2") when every guess has evidence. **"I don't know"** keeps the team value or the recommended option, as a default, not an override (with no team value, the recommended value is stored with a comment so pull does not ask again); "whatever you think" gets one re-ask between two concrete answers. A conventional answer on how the team works ("best practice", "we should") gets one probe: "if you didn't have to justify it, what would you do?". A recap of every answer, with a "Not asked" line, needs an explicit yes before anything is generated.

```markdown
## Deployment
key: deploy.target
Where is this project deployed?
- Kubernetes (recommended)
- Lambda
```

### `team.md`

Team side only: free Markdown for developers — onboarding, tools to install by hand (CLIs, MCP servers with tokens, complex skills), team rules. `/akg:team` shows it; `/akg:setup` ends with one line pointing to it when it exists; `/akg:pull` shows its diff when it changed. **Display only**: it comes from a third party, so akg never runs a command it contains. `/akg:source-init` writes a skeleton (Getting started, Tools to install, Rules). **Team tools check**: at the plugin step of `/akg:setup` (and in `/akg:pull` when `team.md` adds tools), akg reads its tools and checks them read-only (`which`, `claude mcp list`, `claude plugin list`; tokens and access requests are not checkable); missing ones are listed with their command quoted verbatim as `! <command>`, for the developer to run — akg never runs it, even after "ok". No format to follow: the tools are read from the free Markdown.

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
- **Team cache** in `~/.cache/akg/`, refreshed on each `/akg:setup` and `/akg:pull`. Past team versions for pull diffs go to `~/.cache/akg/snapshots/<commit>` and are reused. A local team folder needs no cache; when the cache is read-only (sandboxed session), snapshots go to `$TMPDIR/akg-snapshots/`.
- **`/akg:pull`** never overwrites a local override without approval: it shows the conflict ("team says X, project says Y") and lets the user keep local, take team, or merge. Each non-conflicting change is also proposed (Apply / Keep current); declining a config value makes it an override; a declined list addition or template change is just not applied (`synced` moves on, so it is not proposed again). A new template convention that contradicts the existing code is flagged in one line.
- **Sync reminder.** A `SessionStart` hook gets the team's latest version (`git ls-remote` for a repo, download + hash for a remote file; ~2 s timeout) and compares it with `synced`. Silent when nothing changed or offline; otherwise one line: `akg: team config updated — /akg:pull`. Shown once per new team version (notification state per developer in `~/.cache/akg/`).
- **Branch.** `extends: <source>#<ref>` pins a branch, tag or commit (Claude Code's own `owner/repo#ref` syntax). Each ref has its own cache; the reminder watches that ref; the team marketplace gets the same `ref`. Ignored, with a warning, on a single file.
- **Remote single file** over HTTPS only, no auth in v1. Private team config → use a git repo (developer's git credentials).
- **Empty team repo:** nothing is proposed for now.
- **Creating a team source.** `/akg:source-init` runs in an empty folder or repo: the source is a dedicated repo, no code (a manifest in the folder → warn, offer to stop). `/akg:setup` only mentions it in one line on "No team config". No scan: it asks the team's stacks (several picks, not stored: they drive plugin choice and `relevance`), then every active catalog question phrased for the team (guess = recommended option or the existing answer), skipping `per-project` ones, conditions on project files and `→` checks, then which optional questions projects should answer (`questions:`).
- **Source plugins.** Candidates come from `claude plugin list --available --json`, whose `source` objects (`url`, `git-subdir`…) are reused as is in the source marketplace: **Installed** (the developer's plugins; a relative source in a git marketplace becomes `git-subdir`; a local-directory marketplace is not shareable → excluded with a one-line warning), **Official** (Anthropic plugins from `github.com/anthropics/`, at most 6, picked by judgement from the stacks and answers, each with its reason; downstream projects still use fixed `relevance` rules). One numbered list, grouped, then "Add more plugins?": **from an existing project** (its skills, agents, commands, hooks **copied** into `plugins/<name>/`, the project untouched), the community catalog (on request only: thousands of unreviewed plugins, keyword search too noisy to run by default) or a repo URL. Plugin names must not start with `claude-`.
- **Generated source files**, shown and approved like any other change: `.claude/akg/config.yaml` (answers, `questions`), `.claude-plugin/marketplace.json` (chosen plugins, each with a `relevance` block inferred from what it is for, e.g. `filesRead: ["**/*.tf"]` for `terraform`; general-purpose plugins get none and are proposed on every project), `plugins/<name>/`, a `team.md` skeleton, a short `README.md`, and `git init` if needed. No `questions.md` or `patterns/`: akg defaults apply until the team customizes them. Nothing outward: the developer creates the remote and pushes.
- **Scan first, ask last.** `/akg:setup` scans the project (manifests, README, docs, CI, tests, recent commits), fetches the guessed team source and runs its read-only checks in the first turn, before any question (skill permissions only cover that turn), pre-fills every answer it can infer (with its evidence), and shows **one** summary — stack, commands, layout, what it understood — to confirm or edit in free text. Every question is still asked, with the known answer as the guess: "ok" to confirm, or the developer goes further. Goal: minimal typing, full control.
- **"What I understood" recap.** Part of that summary: purpose, key folders, inferred architecture, integrations; the developer adds or corrects points. The result is the `## Project context` section of `CLAUDE.md`; it belongs to the developer, who edits it directly later. `/akg:pull` never touches it.
- **Single project**: the root is classified `frontend`/`backend` like a sub-project, and its `CLAUDE.md` merges `common` with that template.
- **No dependency on the built-in `/init`.** `/akg:setup` does its own repo analysis and writes `CLAUDE.md`.

## Skill writing guidelines

- Keep output short. The target user is a senior dev who dislikes ceremony.
- Talk in the user's language: the catalog is in English, Claude translates questions and options; generated files stay in English unless the Language answer says otherwise.
- Explain domain jargon (devops, secops…) in one sentence when it appears.
- Ask as an interview, in plain text (`references/rules.md`: Asking), never with `AskUserQuestion` (its 4-option cap hides answers): numbered answers, guess first with its evidence, free values asked directly. Approvals (plugins, files, pull changes) are one numbered list, each item with its proposed action, approved in one reply ("ok", "skip 3").
- Never write files in the target project without showing the change and getting approval.
- `allowed-tools` pre-approves reading akg's own files and the team cache (`Read(/${CLAUDE_PLUGIN_ROOT}/**)`, `Read(~/.cache/akg/**)`; an absolute path in a rule needs a leading `//`, hence the extra `/`), and only the scripts and the read-only commands the scan and checks use (`git log`, `git remote`, `which`, `claude mcp list`, `gh auth status`, `diff` for pull…), so setup runs without approval prompts. These grants apply only during the turn that started the skill: each skill reads its files and runs its checks before the first question.
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
  team/SKILL.md
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
  source/              # empty folder for /akg:source-init
  team/                # local team repo (marketplace + .claude/akg/)
  try.sh               # copy fixtures to a temp dir, print the command to run
evals/                 # claude plugin eval suite: one case per flow, run.sh, lib/fixture.sh scaffold
README.md
```

## Testing

- Load: `claude --plugin-dir <repo>`; reload after edits: `/reload-plugins`; check: `claude plugin validate .`.
- Replay each user flow by hand on `fixtures/`, in manual mode.
- Automated: `evals/run.sh` (`claude plugin eval`, one case per flow on `fixtures/`; see `evals/README.md`). Needs the Bash sandbox (`bubblewrap`, `socat`, and on Ubuntu the AppArmor user-namespace setting). Evals have no simulated user: full cases tell Claude to take each guess as the answer.
