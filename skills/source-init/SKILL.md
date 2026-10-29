---
name: source-init
description: Create a team source for akg in an empty folder or repo — a dedicated repo, no code, that projects extend. Asks the team conventions and the team's stacks, then builds a plugin marketplace from the developer's installed plugins, official Anthropic plugins fitting those stacks, and plugins copied from existing projects. Use when the user runs /akg:source-init or asks to create a team config for akg.
disable-model-invocation: true
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Bash(git rev-parse *), Bash(git config user.name), Bash(git remote *), Bash(claude plugin list *), Bash(claude plugin marketplace list *), Bash(claude plugin validate *)
---

# /akg:source-init

Create the team source in the current folder: a dedicated repo, with no code, that projects `extends`. Its answers become the defaults of every project extending it. Rules for layers, marketplaces and plugin relevance are in [rules.md](${CLAUDE_PLUGIN_ROOT}/references/rules.md) — read it first.

## Ground rules

- **Gather everything in the first turn** (step 1): `allowed-tools` pre-approves only during the turn that started the skill; a later turn would prompt for each read and command.
- **Stay within the pre-approved tools**: read files with Read and find them with Glob/Grep, never `cat`/`ls`/`find` in Bash; run each `allowed-tools` command on its own, never chained (`;`, `&&`, pipes) or prefixed with `cd`.
Same as `/akg:setup`: short messages in the user's language (generated files stay in English); asked as an interview (rules.md: Asking): plain text, numbered answers with a guess first, free values (paths, URLs, keywords) asked directly, never `AskUserQuestion`; **never write a file without showing it and getting approval**; nothing is imposed. A dismissed or empty answer never ends the flow: take the conservative choice (recommended option, no plugin), say it in one line, and continue.

## 1. Gather and check (first turn)

Before the first question, in this turn: read rules.md and `${CLAUDE_PLUGIN_ROOT}/defaults/questions.md`, list the folder, run `git rev-parse --is-inside-work-tree`, `git config user.name`, `claude plugin list --available --json` and `claude plugin marketplace list --json` (used in steps 2 and 4). Then:

- The folder has code (a manifest: `package.json`, `pyproject.toml`, `go.mod`, `composer.json`, `pom.xml`, `Cargo.toml`…, or a `src/`) → say in one line that a team source is a dedicated repo without code, and ask: 1. Stop ← guess (then suggest an empty folder, e.g. `../<org>-claude-team`) · 2. Continue here.
- `.claude/akg/config.yaml` or `.claude-plugin/marketplace.json` already exists → this is already a source: its values are the guesses, source "current", and its plugins stay; say so in one line.

## 2. Team stacks

Ask, as a `multiple` question: "Which stacks does the team work with?" — 1. Front-end JS/TS · 2. Node back-end · 3. PHP · 4. Python · 5. Go · 6. Java/Kotlin · 7. Mobile · 8. Infra (Terraform, Kubernetes); free text for the rest. Guess from an existing marketplace's `relevance`, otherwise from the developer's installed plugins (`claude plugin list --json`: `typescript-lsp` → 1), with the reason; nothing to go on → 1, 2, saying it is only a starting point. Not stored: it only drives the plugin choice and their `relevance` (step 4).

## 3. Team conventions

Ask every active question of the akg catalog (rules.md: Active questions, layer akg only, plus `questions.md` if it exists here), as `/akg:setup` step 5 does, with these differences:
- Say once, before the first question, that these answers become the defaults of every project extending this source.
- Phrase each question for the team ("Where does the team track tickets?").
- No scan: the guess is the recommended option (or the current value of an existing `config.yaml`), so questions come one per message, except where the stacks make the guess obvious (Infra checked → container questions). "I don't know" stores the recommended value with a comment.
- **Skip `per-project`** questions and follow-ups (rules.md), and questions whose condition depends on the project's files ("Ask only if a container setup is detected"); list them in one line ("Left to each project: command environment, local environment, architecture, tracker project, migrations").
- `→` checks (CLI on the PATH, MCP configured) are skipped: they belong to each developer's setup. `→` CLAUDE.md and settings lines are not generated here: projects derive them from the answers.

Then ask, as a `multiple` question, "Which optional questions should projects answer?": the off-by-default catalog prefixes (`deploy`, `git`, `tests`, `db`, `docs`), each with a one-line description; guess: none. Checked ones are added to `questions:` (with the default prefixes) and asked right away like the others.

## 4. Candidate plugins (no questions)

Use the catalog gathered in step 1: `claude plugin list --available --json` (`installed`, and `available`: `pluginId`, `name`, `description`, `marketplaceName`, `source`) and `claude plugin marketplace list --json`. A marketplace entry here reuses the plugin's `source` object **as is** (`url`, `git-subdir`, `github`…).

- **Installed**: plugins the developer has installed (`installed`), except akg itself.
  - `source` is an object → reuse it.
  - `source` is a relative path (`./plugins/x`) in a marketplace from a git or GitHub repo → `{ "source": "git-subdir", "url": "<marketplace repo URL>", "path": "<path without ./>" }`.
  - marketplace from a local directory → not shareable: excluded, one line.
- **Official**: `anthropic-plugin-directory` entries whose `source.url` is under `github.com/anthropics/`. Pick **at most 6** fitting the stacks and the answers, each with a one-line reason: language servers for the stacks (`typescript-lsp`, `pyright-lsp`, `gopls-lsp`, `php-lsp`, `jdtls-lsp`, `kotlin-lsp-anthropics`…), `frontend-design` for front-end, `terraform` for infra, the tracker's plugin (`linear`, `asana`) or code host's (`github`, `gitlab`), review and commit helpers (`code-review`, `pr-review-toolkit`, `commit-commands`), `security-guidance`. Never a domain plugin (legal, finance, bio…) nothing points to. Skip those already in Installed.
- **Relevance** for each candidate, with the fixed signals of rules.md, from what the plugin is for: a language server or stack plugin → `manifestDeps` or `filesRead` for that stack (`typescript-lsp` → `filesRead: ["**/*.ts", "**/*.tsx"]`; a React plugin → `manifestDeps` on `"react"`; `terraform` → `filesRead: ["**/*.tf"]`). General-purpose plugins (review, commits, tracker) → no `relevance` (proposed on every project).

## 5. Pick the plugins

Propose them as one numbered list (rules.md: Asking, Approvals), under two headings — **Installed**, **Official** — numbering running across both: name, reason, relevance ("TypeScript projects" / "every project"). Guess: all. Replies like "ok", "all but 4", "none". Empty group → no heading.

Then ask: "Add more plugins?" — 1. No ← guess · 2. From an existing project (give its path) · 3. Search the community catalog (give keywords) · 4. From a repo (give `github:owner/repo` or git URLs). The developer can give the value right away ("2 ../shop"). Repeat it after each addition until "no".
- **From an existing project**: ask its path if not given. List its skills (`.claude/skills/<name>/`), agents (`.claude/agents/`), commands (`.claude/commands/`) and hooks whose script lives in that repo, and offer them as a numbered list, guess: all. Each one becomes a plugin `plugins/<name>/` here, **copied**; the project is never modified. Relevance from that project's stack, when the item is stack-specific.
- **Search the community catalog**: ask keywords if not given, match them against `name` and `description` of the other `anthropic-plugin-directory` entries, offer the best matches as a numbered list, guess: none (unreviewed). Say in one line that community plugins are not reviewed by Anthropic.
- **From a repo**: ask `github:owner/repo` or git URLs if not given, one per line. Read each repo's `.claude-plugin/plugin.json` when reachable for its name and description; otherwise use the repo name.

Plugin names must not start with `claude-`: rename a copied one (`claude-review` → `review`) and say it.

## 6. Generate

Prepare, without writing yet:

1. **`.claude/akg/config.yaml`**: `questions` (only if it differs from the default list) and every answer at its key (format in rules.md). No `extends`, no `synced`.
2. **`.claude-plugin/marketplace.json`**: `name` = `<folder name>` (no `claude-` prefix), `owner.name` from `git config user.name`, `plugins` = the chosen ones, each with `name`, `source` (`./plugins/<name>` for copied content, the reused object otherwise), `description`, and `relevance` (`topic` + `signals`, same shape as rules.md) when inferred. Existing file → merge: keep its entries, add the new ones, show conflicts on the same name.
3. **`plugins/<name>/`** for each copied item: `.claude-plugin/plugin.json` (`name`, `description`) and the content in plugin layout — `skills/<skill>/`, `agents/<agent>.md`, `commands/<command>.md`, `hooks/hooks.json`. For hooks, copy the script too and rewrite its path from `$CLAUDE_PROJECT_DIR/…` to `${CLAUDE_PLUGIN_ROOT}/…`.
4. **`.claude/akg/team.md`** (only if absent): instructions developers read with `/akg:team`, shown at the end of `/akg:setup` and diffed by `/akg:pull`. A short skeleton for the maintainer to fill, with the stacks and the tracker answer as hints:
   ```markdown
   # <Team> — Claude Code

   ## Getting started
   <!-- What a new developer does first. -->

   ## Tools to install
   <!-- CLIs, MCP servers (with how to get a token), plugins or skills installed by hand. One line each: what, why, the command. -->

   ## Rules
   <!-- Team rules that are not in the questions. -->
   ```
5. **`README.md`** (only if absent), short: what this repo is, how a project uses it (`/akg:setup`, give this repo's URL as the team config), how to add a plugin (an entry in `marketplace.json`), developer instructions (`.claude/akg/team.md`) or a team question (`.claude/akg/questions.md`, format in the akg catalog).
6. **`git init`** if `git rev-parse` says this is not a repo: listed in the review as an action.

## 7. Review and write

Same as `/akg:setup` step 8: each file's content or diff, copied content shown as a list (`<project>/.claude/skills/react-forms/ → plugins/react-forms/skills/react-forms/`), then one numbered list of the files, guess: write all.

Run `claude plugin validate .` and report errors only.

Then, in at most 3 lines:
- what was written;
- next step: commit and push (create the remote first if there is none), then each project runs `/akg:setup` and gives this repo's URL as the team config;
- plugins with an external source are installed once per developer: `/akg:setup` gives the command.
