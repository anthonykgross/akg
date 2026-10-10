---
name: setup
description: First-run setup of Claude Code on a project with akg. Links an optional team config, detects the stack and commands, asks the team/project questions, then proposes CLAUDE.md, .claude/settings.json and plugins. Use when the user runs /akg:setup or asks to set up Claude Code for this project with akg.
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/fetch.sh *)
---

# /akg:setup

Set up Claude Code on this project. Rules for layers, merging, marketplaces and plugin relevance are in [rules.md](${CLAUDE_PLUGIN_ROOT}/references/rules.md) — read it first.

## Ground rules

- The user is a senior developer who dislikes ceremony: short messages, no preamble.
- **Ask every question with the `AskUserQuestion` tool**, never as plain text: 2–4 options, recommended option first with "(Recommended)" in its label and the reason in its description. The tool always adds a free-text "Other" choice, so rough answers are fine. Group up to 4 related questions in one call (one tab each).
- Explain domain jargon in one sentence when it appears.
- **Never write a file without showing it and getting approval.** Nothing is imposed: every value, setting and plugin is a proposal.
- Never invent commands: use the ones the project declares.
- If `.claude/akg/config.yaml` already exists, say so and suggest `/akg:sync` instead; continue only if the user wants to redo the setup (then use the existing values as defaults).

## 1. Team config

Ask with `AskUserQuestion`: "Team config to extend?" — options "None", "Local path", "Git repo / github:owner/repo", "HTTPS URL to a config.yaml"; the user types the actual value via "Other" or in a follow-up. Recommended: none if the user has no team repo.

If given, run `${CLAUDE_PLUGIN_ROOT}/scripts/fetch.sh <source> <project root>` and keep `path`, `kind`, `version`. On failure, say it in one line and offer to retry or continue without a team.

Load the three layers (akg → team → project) as described in rules.md.

## 2. Detect, then confirm

Detect without asking:
- **Stack**: from manifests (`package.json`, `pyproject.toml`, `go.mod`, `composer.json`, `pom.xml`, `Cargo.toml`…) and lockfiles.
- **Commands** (test, lint, build, dev/run): only those declared — package scripts, `Makefile` targets, `composer.json` scripts, `pyproject` tool sections, CI files. Prefer the simplest declared form (`npm test`, `make test`). Leave a command empty rather than inventing one.
- **Sub-projects**: a sub-folder with its own manifest, at most two levels deep (skip `node_modules/`, `vendor/`, `.git/`). `frontend` if its dependencies include a front-end framework (React, Vue, Angular, Svelte, Solid, Next, Nuxt…), else `backend`. Folders without a manifest get no template.

Show it compactly, then ask with `AskUserQuestion` (options "Confirm (Recommended)" / "Edit"; on Edit, ask what to change):

```
Stack:    Node 20, React 18, Vite
Test:     npm test
Lint:     npm run lint
Build:    npm run build
Layout:   single project            (or: web/ → frontend, api/ → backend, infra/ → none)
```

## 3. Questions

Build the merged question list (rules.md). For each question, in order:
- If its `key` already has a value in the merged config (team or project), don't ask: list it in a single "From the team: …" line at the start.
- Otherwise ask it with `AskUserQuestion`, using its options and recommended one, batched by up to 4 (one tab per question; use the `##` title, shortened to 12 chars, as the tab header). Ask the context question alone first, since it sets the defaults of the others (e.g. a POC → no TDD, light review). Free-text answers via "Other" are fine; interpret them.
- A question with no fixed options (e.g. the DoD) gets 2–3 proposed versions as options, built from the context and the detected commands.
- Store the answer at its `key`.

## 4. Plugins

Collect marketplaces and evaluate plugin relevance (rules.md). If there is no marketplace, skip this step silently.

Ask with `AskUserQuestion` and `multiSelect: true`: one option per plugin (label = plugin name, description = its reason, e.g. "package.json depends on react"). Recommended: all. With more than 4 plugins, split into several questions (tabs) by marketplace.

Refused plugins go to `plugins.disabled`.

## 5. Generate

Prepare, without writing yet:

1. **`CLAUDE.md`** at the root from the `common` template; for each sub-project, `<folder>/CLAUDE.md` from its `frontend`/`backend` template. Templates are starting points: fill the placeholders with the confirmed commands and the answers, drop what doesn't apply, add what an answer requires (each question's `→` line says how). Keep it short. If a `CLAUDE.md` already exists, propose a merged version that keeps the user's content.
2. **`.claude/settings.json`**: merged `settings`, `extraKnownMarketplaces` and `enabledPlugins` (rules.md). Merge with the existing file; show conflicts.
3. **`.claude/akg/config.yaml`**: only what rules.md lists for the project file, with `synced` set to the team `version`.

## 6. Review and write

For each file, ask with `AskUserQuestion`: options "Write (Recommended)", "Edit", "Skip", with the file content (or the diff, for an existing file) in the `preview` of the "Write" option. Up to 4 files per call, one tab each. Write only what is approved; on Edit, apply the requested change and ask again.

Then, in at most 3 lines:
- what was written;
- the install command for any external-source plugin;
- next step: commit `.claude/` and `CLAUDE.md` so teammates get the same setup; `/akg:sync` will pull team updates.
