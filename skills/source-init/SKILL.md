---
name: source-init
description: Make the current project the team source that other projects extend with akg. Builds its plugin marketplace from the plugins it already uses and its local skills, agents, commands and hooks. Use when the user runs /akg:source-init, picks "This project is the team source" in /akg:setup, or asks to share this project's Claude Code setup with the team.
disable-model-invocation: true
allowed-tools: Bash(git remote *), Bash(git config user.name), Bash(git rev-parse *), Bash(claude plugin list *), Bash(claude plugin marketplace list *), Bash(claude plugin validate *)
---

# /akg:source-init

Turn this project into the team source: other projects will `extends` it. Rules for layers, marketplaces and plugin relevance are in [rules.md](${CLAUDE_PLUGIN_ROOT}/references/rules.md) — read it first.

## Ground rules

Same as `/akg:setup`: short messages in the user's language (generated files stay in English); every question through the `AskUserQuestion` tool (2–4 options, recommended first, up to 4 per call); **never write, move or delete a file without showing it and getting approval**; nothing is imposed. A dismissed or empty answer never ends the flow: take the conservative choice (no plugin, keep the file where it is), say it in one line, and continue.

## 1. Preconditions

- No `.claude/akg/config.yaml` → say in one line that the project must be set up first, and stop: `/akg:setup`, option "This project is the team source", does both.
- `extends` set in `.claude/akg/config.yaml` → this project already follows a team source. Say so in one line and ask: "Stop (Recommended)" (a source that extends another source is a chain akg does not handle) / "Continue anyway".
- The project becomes the team layer **as is**: its `config.yaml`, and its `questions.md` and `patterns/` if any, are what other projects inherit. Nothing is split or moved out of `config.yaml`; project-specific answers (`arch.style`, `env.runtime`…) are inherited too, harmless since every question is still asked downstream, with the team value as first option. Do not add `extends` or `synced`.

## 2. Candidate plugins (no questions)

Gather silently:
- **Plugins already used**: `enabledPlugins` in `.claude/settings.json`, then `claude plugin list --json` and `claude plugin marketplace list --json` to find each one's marketplace and source.
  - Plugin with its own repo (`source` is `github` or `url` in its marketplace entry) → **referenced**: a marketplace entry with that same `source`, never copied.
  - Plugin hosted inside another marketplace (relative `source`) → that marketplace goes to `marketplaces:` in `config.yaml` instead; say in one line that its other plugins will be proposed too, each by its own relevance.
  - Marketplace from a local directory outside the repo, or private to this machine → cannot be shared: excluded, one line ("`foo`: local marketplace, not shareable").
- **Local content** to package: each skill in `.claude/skills/<name>/`, each agent in `.claude/agents/`, each command in `.claude/commands/`, and the hooks of `.claude/settings.json` whose script lives in the repo. Default: one plugin per skill, agent or command (named after it), one `<project>-hooks` plugin for hooks. Local content already in `plugins/` is skipped.
- **Relevance** for each candidate, inferred from the scan with the signals of rules.md (`manifestDeps`, `filesRead`, `cli`), only with clear evidence: a skill about React in a React project → `manifestDeps` on `"react"`; a Terraform agent → `filesRead: ["**/*.tf"]`. No clear signal → no `relevance` block (proposed on every project).

Plugin names must not start with `claude-`: rename (`claude-review` → `review`) and say it.

## 3. Pick the plugins

Ask with `AskUserQuestion` and `multiSelect: true`: one option per candidate (label = plugin name, description = "used here, from `<source>`" or "local skill, moved to `plugins/<name>/`", plus its relevance: "proposed when `package.json` depends on react" / "proposed everywhere"), plus a last option **"None"**. Recommended: all. More than 3 candidates → one tab per group (used / local), each with its own "None".

Then ask once with `AskUserQuestion`: "Add a plugin from another repo?" — "No (Recommended)" / "Yes". On "Yes", ask in one plain-text message: "Which ones? (`github:owner/repo` or git URL, one per line)" and wait. Read each repo's `.claude-plugin/plugin.json` when reachable for its name and description; otherwise use the repo name.

A user wanting to group local content differently ("one `team-tools` plugin with all skills") says it through "Other": apply it.

## 4. Generate

Prepare, without writing yet:

1. **`.claude-plugin/marketplace.json`**: `name` = `<project>-team` (no `claude-` prefix), `owner.name` from `git config user.name` or the remote owner, `plugins` = the chosen ones, each with `name`, `source` (`./plugins/<name>` for packaged content, the original `source` for referenced ones), `description`, and `relevance` (`topic` + `signals`, same shape as rules.md) when inferred. Existing file → merge: keep its entries, add the new ones, show conflicts on the same name.
2. **`plugins/<name>/`** for each packaged item: `.claude-plugin/plugin.json` (`name`, `description`) and the content in plugin layout — `skills/<skill>/`, `agents/<agent>.md`, `commands/<command>.md`, `hooks/hooks.json`. For hooks, move the script into the plugin too and rewrite its path from `$CLAUDE_PROJECT_DIR/…` to `${CLAUDE_PLUGIN_ROOT}/…`.
3. **This project uses its own plugins**: in `.claude/settings.json`, `extraKnownMarketplaces["<project>-team"] = { "source": { "source": "directory", "path": "." } }` and `enabledPlugins["<name>@<project>-team"] = true` for each packaged one; remove the moved files (`.claude/skills/<name>/`…) and the moved hooks from `settings.json`. Removal is part of the reviewed change, shown as a delete.
4. **`.claude/akg/config.yaml`**: only the added `marketplaces` entries, if any.

## 5. Review and write

Same as `/akg:setup` step 7: for each file, `AskUserQuestion` with "Write (Recommended)", "Edit", "Skip", the content or diff in the `preview` of "Write"; moves and deletes shown as a list (`.claude/skills/review/ → plugins/review/skills/review/`). Up to 4 per call. Skipping a move keeps the local copy: say in one line that the item is now both local and in the marketplace, and do not enable the plugin here.

Run `claude plugin validate .` and report errors only (a warning about the root `CLAUDE.md` is expected).

Then, in at most 3 lines:
- what was written and moved;
- next step: commit and push, then teammates run `/akg:setup` and give `<remote URL>` (from `git remote get-url origin`, or "your repo URL" when there is none) as the team config;
- `/reload-plugins` to load the moved content as plugins in this session.
