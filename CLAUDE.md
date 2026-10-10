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
| `extends` | Team config: a single file (local path or HTTPS URL) or a project (local dir or git repo). Project side only. One value. | — |
| `synced` | Last synced team version: commit SHA (repo) or content hash (file). Project side only, committed. | — |
| `settings` | Raw fragment of Claude Code's `settings.json` (permissions, env, hooks…), deep-merged | `.claude/settings.json` |
| `marketplaces` | Plugin marketplaces to draw plugins from | `extraKnownMarketplaces` |
| `plugins.disabled` | Plugins refused for this project | — |
| *question keys* | Answers, at the key each question declares (e.g. `workflow.tdd`, `deploy.target`) | `CLAUDE.md` |

The project file contains only `extends`, `synced` and overrides: a key present there is an override.

### `questions.md`

Questions asked by `/akg:setup`, in Markdown, interpreted by Claude (rough answers are fine).
- Same `##` title as a lower layer → replaces it. New title → added. Title followed by `skip` → removed.
- `→` lines are free-text instructions for Claude: under an option, applied when it is chosen; at the end of the question, applied whatever the answer. They can ask a follow-up question (with its key), run a **read-only** check (command on PATH, MCP configured, file present) and propose something (a `CLAUDE.md` line, a plugin, a setting). They never install or modify anything: they come from a team repo, i.e. a third party.
- Each question declares the `config.yaml` key its answer goes to (`key: deploy.target`). Base questions follow the same rule (`key: workflow.tdd`); `workflow` is not a special case.
- Base questions: project context (POC, prod, lib…), DoD, TDD, review level. Optional questions come from upper layers.
- A question whose key is already set by a lower layer is not asked; its value is shown instead.

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

- **Three layers: akg → team → project.** The layer closest to the project wins, for every file (`config.yaml`, `questions.md`, `patterns/`). akg ships minimal base questions and templates.
- **The team config is optional.** Without `extends`, `/akg:setup` works the same; `/akg:pull` and the session hook do nothing.
- **Nothing is imposed.** Config, settings, marketplaces and plugins are always proposed and approved by the user.
- **Team repo = a standard Claude Code plugin marketplace** (`.claude-plugin/marketplace.json`) plus `.claude/akg/`. Skills, hooks, agents and MCP servers are distributed as regular plugins; akg does not reinvent distribution, and plugins stay usable without akg.
- **Plugins are enabled, not copied** (`enabledPlugins`). akg evaluates the `relevance` blocks of `marketplace.json` itself: a plugin with `relevance` is proposed only when its signals match the project; a plugin without `relevance` is proposed on every project. No marketplace → no plugin proposed. akg says why each plugin is proposed.
- **`relevance` at setup time uses fixed rules**, never free judgement: `manifestDeps` → regex on the project's manifests; `filesRead` → matching files exist in the repo; `cwd` → glob on the project path; `cli` → command name appears in detected commands; `hosts` → ignored.
- **Settings merge.** Deep merge into `.claude/settings.json`: objects key by key, arrays concatenated and deduplicated; a differing scalar is shown as a conflict. akg never removes anything.
- **Plugins from an external repo** must be installed once per developer; akg gives the exact install command when proposing them.
- **Stack and commands** (test, lint, build) are **detected, then always shown for confirmation or edit**. Prefer commands already declared in the project (`package.json` scripts, `Makefile` targets…); never invent elaborate ones.
- **Team cache** in `~/.cache/akg/`, refreshed on each `/akg:setup` and `/akg:pull`.
- **`/akg:pull`** never overwrites a local override without approval: it shows the conflict ("team says X, project says Y") and lets the user keep local, take team, or merge.
- **Sync reminder.** A `SessionStart` hook gets the team's latest version (`git ls-remote` for a repo, download + hash for a remote file; ~2 s timeout) and compares it with `synced`. Silent when nothing changed or offline; otherwise one line: `akg: team config updated — /akg:pull`. Shown once per new team version (notification state per developer in `~/.cache/akg/`).
- **Remote single file** over HTTPS only, no auth in v1. Private team config → use a git repo (developer's git credentials).
- **Empty team repo:** nothing is proposed for now.
- **"What I understood" recap.** After detection, `/akg:setup` summarises the project (purpose, key folders, inferred architecture, integrations) and lets the developer add or correct points. The result is the `## Project context` section of `CLAUDE.md`; it belongs to the developer, who edits it directly later. `/akg:pull` never touches it.
- **Single project**: the root is classified `frontend`/`backend` like a sub-project, and its `CLAUDE.md` merges `common` with that template.
- **No dependency on the built-in `/init`.** `/akg:setup` does its own repo analysis and writes `CLAUDE.md`.

## Skill writing guidelines

- Keep output short. The target user is a senior dev who dislikes ceremony.
- Explain domain jargon (devops, secops…) in one sentence when it appears.
- Ask questions with the `AskUserQuestion` tool (selectable options, one tab per question, up to 4 per call), 2–4 options, recommended one first. Never as plain text.
- Never write files in the target project without showing the change and getting approval.

## Repository layout (planned)

The repo is both the plugin and its own marketplace (plugin name `akg`; names must not start with `claude-`).

```
.claude-plugin/
  plugin.json
  marketplace.json     # single entry, "source": "./"
skills/
  setup/SKILL.md
  pull/SKILL.md
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
README.md
```

## Testing

- Load: `claude --plugin-dir <repo>`; reload after edits: `/reload-plugins`; check: `claude plugin validate .`.
- Replay each user flow by hand on `fixtures/`. `claude plugin eval` later.
