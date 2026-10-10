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
- **Every option is a real answer.** Never offer an option whose meaning is "type it in Other". When a value can't be an option (a URL, a path, a list of corrections), ask a yes/no-style question first, then ask for the value in **one short plain-text message** and wait for the user's reply.
- Explain domain jargon in one sentence when it appears.
- **Never write a file without showing it and getting approval.** Nothing is imposed: every value, setting and plugin is a proposal.
- Never invent commands: use the ones the project declares.
- **A dismissed or empty answer never ends the flow.** Take the conservative choice for that question (no plugin, keep the current value, skip the file), say it in one line, and continue with the next step. Stop only if the user explicitly asks to stop.
- If `.claude/akg/config.yaml` already exists, say so and suggest `/akg:pull` instead; continue only if the user wants to redo the setup (then use the existing values as defaults).

## 1. Team config

Ask with `AskUserQuestion`: "Extend a team config?" — options "No team config (Recommended)" and "Yes, I have one". If a candidate is obvious (e.g. a sibling folder containing `.claude/akg/`), offer it as a third option with its path.
On "Yes, I have one", ask in one plain-text message: "Where is it? (`github:owner/repo`, git URL, HTTPS URL to a `config.yaml`, or local path)" and wait for the reply.

If given, run `${CLAUDE_PLUGIN_ROOT}/scripts/fetch.sh <source> <project root>` and keep `path`, `kind`, `version`. On failure, say it in one line and offer to retry or continue without a team.

Load the three layers (akg → team → project) as described in rules.md.

## 2. Scan (no questions)

Read before asking anything. Silently gather:
- **Stack**: manifests (`package.json`, `pyproject.toml`, `go.mod`, `composer.json`, `pom.xml`, `Cargo.toml`…) and lockfiles.
- **Commands** (test, lint, build, dev/run): only those declared — package scripts, `Makefile` targets, `composer.json` scripts, `pyproject` tool sections, CI files. Prefer the simplest declared form (`npm test`, `make test`). Leave a command empty rather than inventing one.
- **Layout**: a sub-folder with its own manifest, at most two levels deep (skip `node_modules/`, `vendor/`, `.git/`), is a sub-project: `frontend` if its dependencies include a front-end framework (React, React Native, Vue, Angular, Svelte, Solid, Next, Nuxt…), else `backend`; folders without a manifest get no template. No sub-project → classify the root itself the same way.
- **Understanding**: README, docs, folder structure, entry points, config files (not every file).
- **Signals for the questions**: README and docs, CI and deploy files (`Dockerfile`, `k8s/`, `serverless.yml`, `vercel.json`…), test folders and how many tests exist, the last ~50 commit messages (`git log --oneline -50`: ticket ids like `PROJ-123`, `#123`), issue/PR templates, links in the README (Jira, Linear…), an existing `CLAUDE.md`.

Then **pre-fill every question** of the merged list (rules.md):
- value set by the team or project config → that value, marked `team` / `project`;
- otherwise, an answer you can infer from the scan → that value, with its evidence in a few words ("tests in `src/**/*.test.ts`, 40 files" → TDD yes; "commits reference `SHOP-123`" → Jira);
- otherwise, no pre-fill.

## 3. Confirm what was found

Show **one** compact summary of what was detected and understood, then ask once with `AskUserQuestion`: "Looks right (Recommended)" / "Add or correct something". On the second, ask in one plain-text message what to add or correct (e.g. "edge functions are in `supabase/functions`", "we do DDD") and wait for the reply. Apply the edits and show the summary again until approved. Keep the user's wording for the points they add.

```
Stack     Node 20, React Native 0.74, Supabase
Commands  test: npm test · lint: npm run lint · build: —
Layout    single project → frontend

Understood
- Mobile app for …; screens in src/screens, API calls in src/services
- Supabase: migrations in supabase/migrations, edge functions in supabase/functions
- Architecture: feature folders (guess)
```

The approved "Understood" bullets (plus the user's additions) become the **`## Project context`** section of the root `CLAUDE.md`; points specific to a sub-project also go in that sub-project's `CLAUDE.md`.

## 4. Questions, pre-filled

Ask **every question**, whether or not its answer is already known — set by the team, by the project, or detected by the scan. The developer confirms in one click, or corrects / goes further. Use `AskUserQuestion`, batched by up to 4 (one tab per question; the `##` title, shortened to 12 chars, as the tab header). Each question has at most 4 options, in this order:
1. **The known answer, if any**, labelled "<answer> (Team)", "<answer> (Project)" or "<answer> (Detected)", with its source as description ("commits reference SHOP-123"). Add it as an option if it is not one of the question's own.
2. **The question's other options**, recommended one first (the recommended one is first overall when nothing is known). Keep as many as fit.
3. **"I don't know"** — always the last option.

The tool adds "Other" for free text; interpret rough answers. A question with no fixed options (e.g. the DoD) gets 1–2 proposed versions built from the scan, the known one first.

"I don't know" means: keep the team value if there is one, otherwise use the recommended option; it is a default, not an override, so nothing is written to the project `config.yaml` for it. Say which value was used in one line.

For **every** answer, store it at its `key`, then apply its `→` instructions (rules.md): those under the chosen option, then the question-level ones. Follow-up questions they request (e.g. the Jira URL and project key):
- **value detected by the scan** (URL in the README, `SHOP` from commits `SHOP-123`) → `AskUserQuestion` with the detected value(s) as real options ("SHOP (Detected)"), plus "I don't know";
- **nothing detected** → ask in **one plain-text message** ("Jira URL and project key?") and wait for the reply. Never an `AskUserQuestion` whose option means "type it in Other". Several free values for the same tool go in the same message. Keep checks read-only and report each result in one line ("Jira MCP: not configured — suggested"); collect the proposed `CLAUDE.md` lines, plugins and settings for step 6.

## 5. Plugins

Collect marketplaces and evaluate plugin relevance (rules.md). If there is no marketplace, skip this step silently.

Ask with `AskUserQuestion` and `multiSelect: true`: one option per plugin (label = plugin name, description = its reason, e.g. "package.json depends on react"), plus a last option **"None"** so the user can explicitly pick no plugin. Recommended: all. With more than 3 plugins, split into several questions (tabs) by marketplace, each with its own "None".

Selecting "None", selecting nothing, or dismissing the question all mean "no plugin": refused plugins go to `plugins.disabled`, then **continue to step 6** — choosing no plugin never ends the setup.

## 6. Generate

Prepare, without writing yet:

1. **`CLAUDE.md`** at the root from the `common` template — merged with the `frontend`/`backend` template when the project is a single one — including the approved `## Project context`; for each sub-project, `<folder>/CLAUDE.md` from its `frontend`/`backend` template. Templates are starting points: fill the placeholders with the confirmed commands and the answers, drop what doesn't apply, add what an answer requires (each question's `→` line says how). Keep it short. If a `CLAUDE.md` already exists, propose a merged version that keeps the user's content.
2. **`.claude/settings.json`**: merged `settings`, `extraKnownMarketplaces` and `enabledPlugins` (rules.md). Merge with the existing file; show conflicts.
3. **`.claude/akg/config.yaml`**: only what rules.md lists for the project file, with `synced` set to the team `version`.

## 7. Review and write

For each file, ask with `AskUserQuestion`: options "Write (Recommended)", "Edit", "Skip", with the file content (or the diff, for an existing file) in the `preview` of the "Write" option. Up to 4 files per call, one tab each. Write only what is approved; on Edit, apply the requested change and ask again.

Then, in at most 3 lines:
- what was written;
- the install command for any external-source plugin;
- next step: commit `.claude/` and `CLAUDE.md` so teammates get the same setup; `/akg:pull` will pull team updates.
