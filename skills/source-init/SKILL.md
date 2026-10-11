---
name: source-init
description: Create a team source for akg in an empty folder or repo — a dedicated repo, no code, that projects extend. Asks the team conventions and the team's stacks, then builds a plugin marketplace from the developer's installed plugins, official Anthropic plugins fitting those stacks, and plugins copied from existing projects. Use when the user runs /akg:source-init or asks to create a team config for akg.
disable-model-invocation: true
allowed-tools: Bash(git rev-parse *), Bash(git config user.name), Bash(git remote *), Bash(claude plugin list *), Bash(claude plugin marketplace list *), Bash(claude plugin validate *)
---

# /akg:source-init

Create the team source in the current folder: a dedicated repo, with no code, that projects `extends`. Its answers become the defaults of every project extending it. Rules for layers, marketplaces and plugin relevance are in [rules.md](${CLAUDE_PLUGIN_ROOT}/references/rules.md) — read it first.

## Ground rules

Same as `/akg:setup`: short messages in the user's language (generated files stay in English); every question through the `AskUserQuestion` tool (2–4 options, recommended first, up to 4 per call); free values (paths, URLs, keywords) in one short plain-text message; **never write a file without showing it and getting approval**; nothing is imposed. A dismissed or empty answer never ends the flow: take the conservative choice (recommended option, no plugin), say it in one line, and continue.

## 1. Preconditions

- The folder has code (a manifest: `package.json`, `pyproject.toml`, `go.mod`, `composer.json`, `pom.xml`, `Cargo.toml`…, or a `src/`) → say in one line that a team source is a dedicated repo without code, and ask: "Stop (Recommended)" (then suggest an empty folder, e.g. `../<org>-claude-team`) / "Continue here".
- `.claude/akg/config.yaml` or `.claude-plugin/marketplace.json` already exists → this is already a source: its values are the known answers, labelled "(Current)", and its plugins stay; say so in one line.

## 2. Team stacks

Ask with `AskUserQuestion`, `multiSelect: true`: "Which stacks does the team work with?" — up to 4 options per tab, two tabs: **Front & back** (Front-end JS/TS · Node back-end · PHP · Python) and **Others** (Go · Java/Kotlin · Mobile · Infra (Terraform, Kubernetes)). "Other" for the rest. Not stored: it only drives the plugin choice and their `relevance` (step 4).

## 3. Team conventions

Ask every active question of the akg catalog (rules.md: Active questions, layer akg only, plus `questions.md` if it exists here), as `/akg:setup` step 4 does, with these differences:
- Say once, before the first question, that these answers become the defaults of every project extending this source.
- Phrase each question for the team ("Where does the team track tickets?").
- No scan: options are the question's own, recommended first, then "I don't know" (stores the recommended value with a comment). A known answer from an existing `config.yaml` comes first, "(Current)".
- **Skip `per-project`** questions and follow-ups (rules.md), and questions whose condition depends on the project's files ("Ask only if a container setup is detected"); list them in one line ("Left to each project: command environment, local environment, architecture, tracker project, migrations").
- `→` checks (CLI on the PATH, MCP configured) are skipped: they belong to each developer's setup. `→` CLAUDE.md and settings lines are not generated here: projects derive them from the answers.

Then ask "Which optional questions should projects answer?" (`multiSelect: true`): the off-by-default catalog prefixes (`deploy`, `git`, `tests`, `db`, `docs`), split over two tabs. Checked ones are added to `questions:` (with the default prefixes) and asked right away like the others.

## 4. Candidate plugins (no questions)

Get the catalog once: `claude plugin list --available --json` (`installed`, and `available`: `pluginId`, `name`, `description`, `marketplaceName`, `source`) and `claude plugin marketplace list --json`. A marketplace entry here reuses the plugin's `source` object **as is** (`url`, `git-subdir`, `github`…).

- **Installed**: plugins the developer has installed (`installed`), except akg itself.
  - `source` is an object → reuse it.
  - `source` is a relative path (`./plugins/x`) in a marketplace from a git or GitHub repo → `{ "source": "git-subdir", "url": "<marketplace repo URL>", "path": "<path without ./>" }`.
  - marketplace from a local directory → not shareable: excluded, one line.
- **Official**: `anthropic-plugin-directory` entries whose `source.url` is under `github.com/anthropics/`. Pick **at most 6** fitting the stacks and the answers, each with a one-line reason: language servers for the stacks (`typescript-lsp`, `pyright-lsp`, `gopls-lsp`, `php-lsp`, `jdtls-lsp`, `kotlin-lsp-anthropics`…), `frontend-design` for front-end, `terraform` for infra, the tracker's plugin (`linear`, `asana`) or code host's (`github`, `gitlab`), review and commit helpers (`code-review`, `pr-review-toolkit`, `commit-commands`), `security-guidance`. Never a domain plugin (legal, finance, bio…) nothing points to. Skip those already in Installed.
- **Relevance** for each candidate, with the fixed signals of rules.md, from what the plugin is for: a language server or stack plugin → `manifestDeps` or `filesRead` for that stack (`typescript-lsp` → `filesRead: ["**/*.ts", "**/*.tsx"]`; a React plugin → `manifestDeps` on `"react"`; `terraform` → `filesRead: ["**/*.tf"]`). General-purpose plugins (review, commits, tracker) → no `relevance` (proposed on every project).

## 5. Pick the plugins

Ask with `AskUserQuestion` and `multiSelect: true`, one tab per group — **Installed**, **Official** — at most 3 plugins per tab plus a last option **"None"** (split a group over two tabs when needed). Label = plugin name; description = the reason and the relevance ("TypeScript projects" / "every project"). Recommended: all. Empty group → no tab.

Then ask: "Add more plugins?" — "No (Recommended)" / "From an existing project" / "Search the community catalog" / "From a repo". Repeat it after each addition until "No".
- **From an existing project**: ask its path in one plain-text message. List its skills (`.claude/skills/<name>/`), agents (`.claude/agents/`), commands (`.claude/commands/`) and hooks whose script lives in that repo, and offer them (multi-select, plus "None"). Each one becomes a plugin `plugins/<name>/` here, **copied**; the project is never modified. Relevance from that project's stack, when the item is stack-specific.
- **Search the community catalog**: ask keywords in one plain-text message, match them against `name` and `description` of the other `anthropic-plugin-directory` entries, offer the 4 best (multi-select, plus "None"). Say in one line that community plugins are not reviewed by Anthropic.
- **From a repo**: ask `github:owner/repo` or git URLs in one plain-text message, one per line. Read each repo's `.claude-plugin/plugin.json` when reachable for its name and description; otherwise use the repo name.

Plugin names must not start with `claude-`: rename a copied one (`claude-review` → `review`) and say it.

## 6. Generate

Prepare, without writing yet:

1. **`.claude/akg/config.yaml`**: `questions` (only if it differs from the default list) and every answer at its key (format in rules.md). No `extends`, no `synced`.
2. **`.claude-plugin/marketplace.json`**: `name` = `<folder name>` (no `claude-` prefix), `owner.name` from `git config user.name`, `plugins` = the chosen ones, each with `name`, `source` (`./plugins/<name>` for copied content, the reused object otherwise), `description`, and `relevance` (`topic` + `signals`, same shape as rules.md) when inferred. Existing file → merge: keep its entries, add the new ones, show conflicts on the same name.
3. **`plugins/<name>/`** for each copied item: `.claude-plugin/plugin.json` (`name`, `description`) and the content in plugin layout — `skills/<skill>/`, `agents/<agent>.md`, `commands/<command>.md`, `hooks/hooks.json`. For hooks, copy the script too and rewrite its path from `$CLAUDE_PROJECT_DIR/…` to `${CLAUDE_PLUGIN_ROOT}/…`.
4. **`README.md`** (only if absent), short: what this repo is, how a project uses it (`/akg:setup`, answer "Yes, I have one", give this repo's URL), how to add a plugin (an entry in `marketplace.json`) or a team question (`.claude/akg/questions.md`, format in the akg catalog).
5. **`git init`** if `git rev-parse` says this is not a repo: listed in the review as an action.

## 7. Review and write

Same as `/akg:setup` step 7: for each file, `AskUserQuestion` with "Write (Recommended)", "Edit", "Skip", the content or diff in the `preview` of "Write"; copied content shown as a list (`<project>/.claude/skills/react-forms/ → plugins/react-forms/skills/react-forms/`). Up to 4 per call.

Run `claude plugin validate .` and report errors only.

Then, in at most 3 lines:
- what was written;
- next step: commit and push (create the remote first if there is none), then each project runs `/akg:setup`, answers "Yes, I have one" and gives this repo's URL;
- plugins with an external source are installed once per developer: `/akg:setup` gives the command.
