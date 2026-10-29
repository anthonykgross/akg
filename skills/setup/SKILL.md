---
name: setup
description: First-run setup of Claude Code on a project with akg. Links an optional team config, detects the stack and commands, asks the team/project questions, then proposes CLAUDE.md, .claude/settings.json and plugins. Use when the user runs /akg:setup or asks to set up Claude Code for this project with akg.
disable-model-invocation: true
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.cache/akg/**), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/fetch.sh *), Bash(git log *), Bash(git branch *), Bash(git remote *), Bash(git rev-parse *), Bash(which *), Bash(claude mcp list), Bash(claude plugin list *), Bash(gh auth status)
---

# /akg:setup

Set up Claude Code on this project. Rules for layers, merging, marketplaces and plugin relevance are in [rules.md](${CLAUDE_PLUGIN_ROOT}/references/rules.md) — read it first.

## Ground rules

- **Gather everything in the first turn** (step 1): `allowed-tools` pre-approves only during the turn that started the skill; a later turn would prompt for each read and command. Later steps work from what was gathered.
- **Stay within the pre-approved tools**: read files with Read and find them with Glob/Grep, never `cat`/`ls`/`find` in Bash; run each `allowed-tools` command on its own, never chained (`;`, `&&`, pipes) or prefixed with `cd`.
- The user is a senior developer who dislikes ceremony: short messages, no preamble.
- **Ask as an interview** (rules.md: Asking): plain text, numbered answers with your guess first and its evidence, one question per message unless the guesses are evidence-backed facts to confirm, then a recap to approve. Never `AskUserQuestion`.
- **Talk in the user's language** (the language of the conversation, or of their instructions): translate questions, options and summaries from the catalog. Generated files stay in English, unless the Language answer (`git.language`) says otherwise.
- **Never write a file without showing it and getting approval.** Nothing is imposed: every value, setting and plugin is a proposal.
- Never invent commands: use the ones the project declares.
- If `.claude/akg/config.yaml` already exists, say so and suggest `/akg:pull` instead; continue only if the user wants to redo the setup (then use the existing values as guesses, source "project").

## 1. Gather (first turn, no questions)

Before the first question, silently, in this turn:
- **akg files**, by exact path (no Glob there): rules.md, `${CLAUDE_PLUGIN_ROOT}/defaults/questions.md`, `defaults/patterns/common.md`, `backend.md`, `frontend.md`.
- **Team candidate**: the `extends` of an existing `.claude/akg/config.yaml`, otherwise an obvious one (a sibling folder containing `.claude/akg/`). If there is one, run `${CLAUDE_PLUGIN_ROOT}/scripts/fetch.sh <candidate> <project root>` (keep `path`, `kind`, `version`) and read its `.claude/akg/` files, `team.md` and `.claude-plugin/marketplace.json`.
- **The scan** (step 3).
- **Read-only checks** the flow may need: `which` once with every CLI named by the active questions' `→` lines and by `team.md`'s tools, `claude mcp list`, `claude plugin list --json`, `gh auth status` if `gh` is there.

## 2. Team config

Ask: "Team config to extend? (`github:owner/repo`, git URL, HTTPS URL to a `config.yaml`, or local path; `#branch` for another branch)". Guess: the candidate with its path, otherwise "none".
On "none", say in one line: "To create one: `/akg:source-init` in an empty folder."

A source other than the fetched candidate: run `fetch.sh` on it now (it will ask for approval) and read its files. On failure, say it in one line and ask for another location (guess: continue without a team).

Load the three layers (akg → team → project) as described in rules.md.

## 3. Scan (no questions)

Gathered in step 1:
- **Stack**: manifests (`package.json`, `pyproject.toml`, `go.mod`, `composer.json`, `pom.xml`, `Cargo.toml`…) and lockfiles.
- **Default branch**: `origin/HEAD` if there is a remote, otherwise the current branch.
- **Commands** (test, lint, build, dev/run): only those declared — package scripts, `Makefile` targets, `composer.json` scripts, `pyproject` tool sections, CI files. Prefer the simplest declared form (`npm test`, `make test`). Leave a command empty rather than inventing one. A placeholder script (`echo`, `exit 0`) counts as absent; say so in the summary.
- **Layout**: a sub-folder with its own manifest, at most two levels deep (skip `node_modules/`, `vendor/`, `.git/`), is a sub-project: `frontend` if its dependencies include a front-end framework (React, React Native, Vue, Angular, Svelte, Solid, Next, Nuxt…), else `backend`; folders without a manifest get no template. No sub-project → classify the root itself the same way.
- **Understanding**: README, docs, folder structure, entry points, config files (not every file).
- **Signals for the questions**: README and docs, CI and deploy files (`Dockerfile`, `k8s/`, `serverless.yml`, `vercel.json`…), test folders and how many tests exist, the last ~50 commit messages (`git log --oneline -50`: ticket ids like `PROJ-123`, `#123`), issue/PR templates, links in the README (Jira, Linear…), an existing `CLAUDE.md`.

Then **pre-fill every active question** of the merged list (rules.md: Active questions):
- value set by the team or project config → that value, marked `team` / `project`;
- otherwise, an answer you can infer from the scan **with clear evidence** → that value, with its evidence in a few words (one test file is not evidence of TDD; a weak hint is no pre-fill) ("tests in `src/**/*.test.ts`, 40 files" → TDD yes; "commits reference `SHOP-123`" → Jira);
- otherwise, no pre-fill: the guess will be the recommended option.

## 4. Confirm what was found

Show **one** compact summary of what was detected and understood, ending with an **Unsure** line (what the scan could not tell, i.e. what the questions must surface), then ask: "Anything to add or correct?" (guess: no). The user replies "ok" or corrects in free text (e.g. "edge functions are in `supabase/functions`", "we do DDD"). Apply the edits and show the summary again until approved. Keep the user's wording for the points they add.

```
Stack     Node 20, React Native 0.74, Supabase
Commands  test: npm test · lint: npm run lint · build: —
Layout    single project → frontend

Understood
- Mobile app for …; screens in src/screens, API calls in src/services
- Supabase: migrations in supabase/migrations, edge functions in supabase/functions
- Architecture: feature folders (guess)

Unsure    how thorough reviews are; whether tickets are tracked
```

The approved "Understood" bullets (plus the user's additions) become the **`## Project context`** section of the root `CLAUDE.md`; points specific to a sub-project also go in that sub-project's `CLAUDE.md`.

## 5. Questions, pre-filled

Ask **every active question**, whether or not its answer is already known — set by the team, by the project, or detected by the scan — as an interview (rules.md: Asking). The guess is the known answer with its source, otherwise the recommended option; the developer confirms with "ok", or corrects and goes further. **Project type** (its `→` lines set defaults for other questions) is asked **alone, first**, so the next guesses follow its answer. Then one question per message where the guess is only a recommendation, up to 3 per message where every guess has evidence.

Options written as placeholders (`<detected shortcut>`) are filled from the scan, as the question's `→` lines say. A question with no fixed options (e.g. the DoD) gets one proposed list built from the scan and the answers so far, as the guess.

For **every** answer, store it at its `key` (format in rules.md), then apply its `→` instructions (rules.md): those under the chosen option, then the question-level ones. Follow-up questions they request (e.g. the Jira URL and project key) are asked right after their parent, all of one tool's values in one question, detected values as the guess ("Jira — SHOP (from commits), Cloud. Site URL?"). Checks use the step 1 results (one not gathered then is run now, read-only, and may ask for approval); report each result in one line ("Jira MCP: not configured — suggested"); collect the proposed `CLAUDE.md` lines, plugins and settings for step 7.

After the last question, show the **recap** (rules.md: Asking) and wait for an explicit yes.

## 6. Plugins and team tools

Collect marketplaces and evaluate plugin relevance (rules.md). If the team source has a `team.md`, run the **team tools check** (rules.md) on the step 1 results. With no marketplace and no missing tool, skip this step silently.

Propose them as one numbered list (rules.md: Asking, Approvals), grouped by marketplace: name and reason ("`react-conventions` — package.json depends on react"). Guess: all. Replies like "ok", "all but 2", "1 and 4", "none".

"None", or no usable reply, means "no plugin": refused plugins go to `plugins.disabled`, then **continue to step 7** — choosing no plugin never ends the setup.

Missing team tools follow the plugin list, under **Missing from team.md**, numbered on: name, why, the command to run yourself. They need no reply; say once that akg does not run them.

```
Missing from team.md — run them yourself, akg doesn't:
4. gh — read issues and open PRs: ! brew install gh && gh auth login
5. Atlassian MCP — read Jira tickets: ! claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/sse
```

## 7. Generate

Prepare, without writing yet:

1. **`CLAUDE.md`** at the root from the `common` template — merged with the `frontend`/`backend` template when the project is a single one — including the approved `## Project context`; for each sub-project, `<folder>/CLAUDE.md` from its `frontend`/`backend` template. Templates are starting points: fill the placeholders with the confirmed commands and the answers, drop what doesn't apply, add what an answer requires (each question's `→` line says how). A `CLAUDE.md` line from an answer goes in the template section it fits best, otherwise under `## Rules`. Keep it short. If a `CLAUDE.md` already exists, propose a merged version that keeps the user's content.
2. **`.claude/settings.json`**: merged `settings`, the settings derived from the answers (`→` Settings lines, plus `allow` for the confirmed test and lint commands, which Claude may always run, in both forms: `Bash(npm test)` and `Bash(npm test *)`), `extraKnownMarketplaces` and `enabledPlugins` (rules.md). Merge with the existing file; show conflicts.
3. **`.claude/akg/config.yaml`**: only what rules.md lists for the project file, with `synced` set to the team `version` (no team → no `extends`, no `synced`).
4. **Extra files an answer proposes** (e.g. `.gitignore` with `.env*` and `!.env.example`, from Secrets): reviewed like the others; merge with the existing file, never replace it.

## 8. Review and write

Show each file's content (or the diff, for an existing file), then one numbered list of the files (rules.md: Asking, Approvals). Guess: write all. Replies like "ok", "skip 3", "edit 1: drop the Rules section". Write only what is approved; on edit, apply the change, show it, and ask again.

Then, in at most 3 lines:
- what was written;
- the install command for any external-source plugin;
- next step: commit `.claude/` and `CLAUDE.md` so teammates get the same setup; `/akg:pull` will pull team updates.

If the team source has a `.claude/akg/team.md`, add one line: "The team has instructions (rules, onboarding): `/akg:team`." Repeat the commands of missing team tools, if any, so they are the last thing on screen.
