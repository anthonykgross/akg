---
name: pull
description: Pull team config updates into a project set up with akg, without overwriting local overrides. Shows what changed on the team side, surfaces conflicts with local overrides, proposes new questions and plugins. Use when the user runs /akg:pull or the akg session reminder says the team config was updated.
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/fetch.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.sh *)
---

# /akg:pull

Bring the team's latest config into this project. Rules for layers, merging, marketplaces and plugin relevance are in [rules.md](${CLAUDE_PLUGIN_ROOT}/references/rules.md) — read it first.

## Ground rules

Same as `/akg:setup`: short messages; every question through the `AskUserQuestion` tool (2–4 options, recommended first, up to 4 per call); **never write a file without showing it and getting approval**; nothing is imposed; **the local project always wins**. A dismissed or empty answer never ends the flow: take the conservative choice (keep local, no plugin, skip the file), say it in one line, and continue.

## 1. Check

- Read `.claude/akg/config.yaml`. Missing → "Project not set up with akg: run `/akg:setup`." Stop.
- No `extends` → "No team config configured." Stop.
- Run `${CLAUDE_PLUGIN_ROOT}/scripts/fetch.sh <extends> <project root>`. On failure, say it in one line and stop.
- `version` equals `synced` → "Up to date." Stop.

## 2. What changed on the team side

Run `${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.sh <kind> <path> <synced>` to get the team config as it was at the last sync.

- **Snapshot available**: compare old vs new team `config.yaml`, `questions.md`, `patterns/` and `.claude-plugin/marketplace.json`. Only what differs is a change.
- **Snapshot unavailable** (no history): compare the current team config with the project's current state instead. Don't raise override conflicts in this mode; just list kept overrides in one line ("Kept local: `workflow.tdd: false` (team: true)").

If nothing relevant changed (e.g. a commit touching only the team's README), update `synced` after approval and stop.

## 3. Resolve each change

| Change on the team side | Project overrides the key? | Action |
|---|---|---|
| Value added or changed | No | Propose applying it to the generated files. |
| Value added or changed | Yes | Conflict: ask "Team says X, project says Y" → **Keep local (Recommended)** / Take team / Merge (lists and text only). |
| Value removed | — | Nothing to do on generated files beyond what the user approves; akg never removes settings. Mention it in one line. |
| New active question (new in the catalog/team list, or newly enabled by `questions`) whose key has no value | — | Ask it like `/akg:setup` step 4: known answer first ("(Team)" / "(Detected)"), then its options, then "I don't know". |
| Question replaced or removed | — | Ignore unless its key has no value. |
| Template (`patterns/`) changed | — | Propose the equivalent targeted edit in the matching `CLAUDE.md` files (don't regenerate them: the user may have edited them). Never touch the `## Project context` section: it belongs to the developer. |
| New plugin or marketplace | — | Evaluate relevance (rules.md) and propose, `multiSelect`, with reasons and a last "None" option. None or empty selection = all declined; continue. |

Group conflicts in one `AskUserQuestion` call (one tab each, up to 4).

**Refusing a team change makes it a local override**: if the user declines a non-overridden value, write the current value into the project `config.yaml`; a declined plugin goes to `plugins.disabled`. That way it is not proposed again.

## 4. Review and write

Prepare the updated files: the affected `CLAUDE.md` files (targeted edits), `.claude/settings.json` (deep merge, rules.md), `.claude/akg/config.yaml` (new overrides, `synced: <version>`).

For each file, ask with `AskUserQuestion`: "Write (Recommended)" / "Edit" / "Skip", with the diff in the `preview` of "Write". Write only what is approved. Always update `synced`, even if every change was declined (they are now overrides).

End with at most 3 lines: what changed, install commands for any external-source plugin, and "commit `.claude/` so teammates don't get the reminder again".
