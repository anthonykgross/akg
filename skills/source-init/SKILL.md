---
name: source-init
description: Make the current project the team source that other projects extend with akg. Asks the setup questions as team defaults, then builds its plugin marketplace from the plugins it uses, official Anthropic plugins fitting the stack, and its local skills, agents, commands and hooks. Use when the user runs /akg:source-init, picks "This project is the team source" in /akg:setup, or asks to share this project's Claude Code setup with the team.
disable-model-invocation: true
allowed-tools: Bash(git log *), Bash(git branch *), Bash(git remote *), Bash(git rev-parse *), Bash(git config user.name), Bash(which *), Bash(claude mcp list), Bash(gh auth status), Bash(claude plugin list *), Bash(claude plugin marketplace list *), Bash(claude plugin validate *)
---

# /akg:source-init

Turn this project into the team source: other projects will `extends` it, and its answers become their defaults. Rules for layers, marketplaces and plugin relevance are in [rules.md](${CLAUDE_PLUGIN_ROOT}/references/rules.md) — read it first. The setup flow is in [setup](${CLAUDE_PLUGIN_ROOT}/skills/setup/SKILL.md).

## Ground rules

Same as `/akg:setup`: short messages in the user's language (generated files stay in English); every question through the `AskUserQuestion` tool (2–4 options, recommended first, up to 4 per call); **never write, move or delete a file without showing it and getting approval**; nothing is imposed. A dismissed or empty answer never ends the flow: take the conservative choice (no plugin, keep the file where it is), say it in one line, and continue.

## 1. Preconditions

- `extends` set in `.claude/akg/config.yaml` → this project already follows a team source. Say so in one line and ask: "Stop (Recommended)" (a source that extends another source is a chain akg does not handle) / "Continue anyway".
- The project becomes the team layer **as is**: its `config.yaml`, and its `questions.md` and `patterns/` if any, are what other projects inherit. No `extends`, no `synced`. Answers that only make sense for this project are left out (step 2), so each extending project answers them itself.

## 2. Setup, as team defaults

Run `/akg:setup` steps 2 to 4 (scan, confirm what was found, every active question), with these differences:
- No team layer: only akg → project.
- An existing `.claude/akg/config.yaml` is not a reason to stop: its answers are the known answers, labelled "(Project)".
- Say once, before the first question, that these answers become the defaults of every project extending this one.
- Ask about the team's conventions, not this project's: phrase each question for the team ("Where does the team track tickets?"). Scan results are still offered first, labelled "(Detected)".
- **Skip `per-project`** questions and follow-ups (rules.md): not asked, not stored (e.g. GitHub Issues is asked, the repository is not; Jira's site URL and hosting are asked, its project key is not). An existing value for such a key is removed from `config.yaml`, shown in the review. List the skipped ones in one line ("Left to each project: command environment, local environment, architecture, tracker project").
- The `CLAUDE.md` of this project is generated from the team answers only: say in one line that project-specific details (its tracker project, its folders) can be added by hand.
- Setup step 5 (plugins) is replaced by steps 3–4 below.

## 3. Candidate plugins (no questions)

Get the catalog once: `claude plugin list --available --json` (`available`: `pluginId`, `name`, `description`, `marketplaceName`, `source`) and `claude plugin marketplace list --json`. A marketplace entry here reuses the plugin's `source` object **as is** (`url`, `git-subdir`, `github`…). Gather silently:

- **Used**: plugins in `enabledPlugins` of `.claude/settings.json`.
  - `source` is an object → reuse it.
  - `source` is a relative path (`./plugins/x`) in a marketplace from a git or GitHub repo → `{ "source": "git-subdir", "url": "<marketplace repo URL>", "path": "<path without ./>" }`.
  - marketplace from a local directory (`source: directory`) → cannot be shared: excluded, one line ("`code-review`: local marketplace, not shareable").
- **Official**: `anthropic-plugin-directory` entries whose `source.url` is under `github.com/anthropics/`. Pick **at most 6** that fit the scan and the answers, each with a one-line reason: a language server for the main language (`typescript-lsp`, `pyright-lsp`, `gopls-lsp`, `php-lsp`…), `frontend-design` for a front-end, `playwright` with e2e tests, the tracker's plugin (`linear`, `asana`) or code host's (`github`, `gitlab`), `terraform` with `.tf` files, review and commit helpers (`code-review`, `pr-review-toolkit`, `commit-commands`), `security-guidance`. Never a domain plugin (legal, finance, bio…) the project shows no sign of. Skip those already in Used.
- **Local**: each skill in `.claude/skills/<name>/`, each agent in `.claude/agents/`, each command in `.claude/commands/`, and the hooks of `.claude/settings.json` whose script lives in the repo. One plugin per skill, agent or command (named after it), one `<project>-hooks` plugin for hooks. Content already in `plugins/` is skipped.
- **Relevance** for each candidate, with the fixed signals of rules.md (`manifestDeps`, `filesRead`, `cli`), only with clear evidence: React skill → `manifestDeps` on `"react"`; `terraform` → `filesRead: ["**/*.tf"]`; `typescript-lsp` → `filesRead: ["**/*.ts", "**/*.tsx"]`. General-purpose plugins (review, commits) → no `relevance` (proposed on every project).

Plugin names must not start with `claude-`: rename a local one (`claude-review` → `review`) and say it.

## 4. Pick the plugins

Ask with `AskUserQuestion` and `multiSelect: true`, one tab per group — **Used**, **Official**, **Local** — at most 3 plugins per tab plus a last option **"None"** (split a group over two tabs when needed). Label = plugin name; description = the reason ("enabled here", "TypeScript project", "local skill, moved to `plugins/<name>/`") and the relevance ("proposed when `package.json` depends on react" / "proposed everywhere"). Recommended: all. Empty group → no tab.

Then ask once: "Add more plugins?" — "No (Recommended)" / "Search the community catalog" / "From a repo".
- **Search the community catalog**: ask in one plain-text message for keywords, match them against `name` and `description` of the other `anthropic-plugin-directory` entries, and offer the 4 best (multi-select, plus "None"), with their description. Say in one line that community plugins are not reviewed by Anthropic. Repeat the "Add more plugins?" question afterwards.
- **From a repo**: ask in one plain-text message for `github:owner/repo` or git URLs, one per line. Read each repo's `.claude-plugin/plugin.json` when reachable for its name and description; otherwise use the repo name.

A user wanting to group local content differently ("one `team-tools` plugin with all skills") says it through "Other": apply it.

## 5. Generate

Prepare, without writing yet:

1. **Setup files** (`/akg:setup` step 6): `CLAUDE.md`, `.claude/settings.json`, `.claude/akg/config.yaml` with **all** answers (no `extends`, no `synced`), extra files.
2. **`.claude-plugin/marketplace.json`**: `name` = `<project>-team` (no `claude-` prefix), `owner.name` from `git config user.name` or the remote owner, `plugins` = the chosen ones, each with `name`, `source` (`./plugins/<name>` for local content, the reused object otherwise), `description`, and `relevance` (`topic` + `signals`, same shape as rules.md) when inferred. Existing file → merge: keep its entries, add the new ones, show conflicts on the same name.
3. **`plugins/<name>/`** for each local item: `.claude-plugin/plugin.json` (`name`, `description`) and the content in plugin layout — `skills/<skill>/`, `agents/<agent>.md`, `commands/<command>.md`, `hooks/hooks.json`. For hooks, move the script into the plugin too and rewrite its path from `$CLAUDE_PROJECT_DIR/…` to `${CLAUDE_PLUGIN_ROOT}/…`.
4. **This project uses its own marketplace** (in the `.claude/settings.json` of item 1): `extraKnownMarketplaces["<project>-team"] = { "source": { "source": "directory", "path": "." } }`, `enabledPlugins["<name>@<project>-team"] = true` for each chosen plugin; remove the moved files (`.claude/skills/<name>/`…) and the moved hooks. Removal is part of the reviewed change, shown as a delete.

## 6. Review and write

Same as `/akg:setup` step 7: for each file, `AskUserQuestion` with "Write (Recommended)", "Edit", "Skip", the content or diff in the `preview` of "Write"; moves and deletes shown as a list (`.claude/skills/react-forms/ → plugins/react-forms/skills/react-forms/`). Up to 4 per call. Skipping a move keeps the local copy: say in one line that the item is now both local and in the marketplace, and do not enable that plugin here.

Run `claude plugin validate .` and report errors only (a warning about the root `CLAUDE.md` is expected).

Then, in at most 3 lines:
- what was written and moved;
- the install command for plugins with an external source (`claude plugin install <plugin>@<project>-team --scope project`);
- next step: commit and push, then teammates run `/akg:setup` and give `<remote URL>` (from `git remote get-url origin`, or "your repo URL" when there is none) as the team config; `/reload-plugins` to load the moved content here.
