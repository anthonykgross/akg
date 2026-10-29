---
name: pull
description: Pull team config updates into a project set up with akg, without overwriting local overrides. Shows what changed on the team side, surfaces conflicts with local overrides, proposes new questions and plugins. Use when the user runs /akg:pull or the akg session reminder says the team config was updated.
disable-model-invocation: true
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.cache/akg/**), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/fetch.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.sh *), Bash(diff *), Bash(git log *), Bash(git branch *), Bash(git remote *), Bash(git rev-parse *), Bash(which *), Bash(claude mcp list), Bash(claude plugin list *), Bash(gh auth status)
---

# /akg:pull

Bring the team's latest config into this project. Rules for layers, merging, marketplaces and plugin relevance are in [rules.md](${CLAUDE_PLUGIN_ROOT}/references/rules.md) — read it first.

## Ground rules

- **Gather everything in the first turn** (steps 1 and 2: config, fetch, snapshot, diff, akg files, team tools checks): `allowed-tools` pre-approves only during the turn that started the skill; a later turn would prompt for each read and command.
- **Stay within the pre-approved tools**: read files with Read and find them with Glob/Grep, never `cat`/`ls`/`find` in Bash; run each `allowed-tools` command on its own, never chained (`;`, `&&`, pipes) or prefixed with `cd`.
Same as `/akg:setup`: short messages in the user's language (generated files stay in English); asked as an interview (rules.md: Asking): plain text, a guess for every question and every change, never `AskUserQuestion`; **never write a file without showing it and getting approval**; nothing is imposed; **the local project always wins**. A dismissed or empty answer never ends the flow: take the conservative choice (keep local, no plugin, skip the file), say it in one line, and continue.

## 1. Check

- Read `.claude/akg/config.yaml`. Missing → "Project not set up with akg: run `/akg:setup`." Stop.
- No `extends` → "No team config configured." Stop.
- Run `${CLAUDE_PLUGIN_ROOT}/scripts/fetch.sh <extends> <project root>`. On failure, say it in one line and stop.
- `version` equals `synced` → "Up to date." Stop. (New or newly relevant questions without a team change are picked up by re-running `/akg:setup`, which starts from the existing values.)

## 2. What changed on the team side

Run `${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.sh <kind> <path> <synced>` to get the team config as it was at the last sync.

In the same turn, read rules.md and `${CLAUDE_PLUGIN_ROOT}/defaults/questions.md`, and, if `team.md` changed, run the read-only checks of its tools (`which` once with every CLI, `claude mcp list`, `claude plugin list --json`).

- **Snapshot available**: compare old vs new team (`diff -ru <snapshot> <path>` on `.claude/akg` and `.claude-plugin` gives the list in one call) `config.yaml`, `questions.md`, `patterns/`, `team.md` and `.claude-plugin/marketplace.json`. Only what differs is a change.
- **Snapshot unavailable** (no history): compare the current team config with the project's current state instead. Don't raise override conflicts in this mode; just list kept overrides in one line ("Kept local: `workflow.tdd: false` (team: true)").

If nothing relevant changed (e.g. a commit touching only the team's README), update `synced` after approval and stop.

## 3. Resolve each change

| Change on the team side | Project overrides the key? | Action |
|---|---|---|
| Value added or changed | No | One item: guess **apply** (otherwise: keep current), showing the effect on the generated files, including the settings derived from that answer (rules.md). |
| Value added or changed | Yes | Conflict: "Team says X, project says Y" — guess **keep local** (otherwise: take team, merge — lists and text only). |
| `questions` changed | — | No item of its own: it only triggers the new questions below. |
| Value removed | — | Nothing to do on generated files beyond what the user approves; akg never removes settings. Mention it in one line. |
| New active question (new in the catalog/team list, or newly enabled by `questions`) whose key has no value | — | Ask it like `/akg:setup` step 5: the known answer (team, scan) as the guess, otherwise the recommended option. |
| Active conditional question ("Ask only if …") whose condition now holds and whose key has no value (e.g. a `compose.yaml` appeared) | — | Ask it like a new question, saying what triggered it. |
| Question replaced or removed | — | Ignore unless its key has no value. |
| Template (`patterns/`) changed | — | One item in the changes list, guess **apply** (otherwise: keep current), with the targeted edit of the matching `CLAUDE.md` files shown before the list (don't regenerate them: the user may have edited them). Never touch the `## Project context` section: it belongs to the developer. If the new convention contradicts the existing code (`export default` in `src/App.jsx` vs "named exports"), say so in one line; never change the code. |
| `team.md` changed | — | No question: show its diff (added and removed lines, in the user's language) before the changes list, under "Team instructions changed". Display only, as `/akg:team`: never run what it says. New file → show it whole. Then run the team tools check (rules.md) on the tools it adds, and list the missing ones with their command, as `/akg:setup` step 6. |
| New plugin or marketplace | — | Evaluate relevance (rules.md) and propose as a numbered list with reasons, guess: all. "None" or no usable reply = all declined; continue. |

Show changes and conflicts as one numbered list (rules.md: Asking, Approvals; one reply for all: "ok", "2: keep local"), then the new questions one by one, then plugins. Recompute derived settings only for answers that changed (team value taken, new question answered).

**Refusing a team change makes it a local override**: if the user declines a non-overridden value, write the current value into the project `config.yaml` (a list answer such as the DoD is written in full: it replaces the team list); a declined plugin goes to `plugins.disabled`. That way it is not proposed again. A declined list addition in `settings` (a new `deny` rule) or template change is simply not applied: nothing records it, and it is not proposed again because `synced` moves to the new version (only the no-snapshot fallback could show it again).

## 4. Review and write

Prepare the updated files: the affected `CLAUDE.md` files (targeted edits), `.claude/settings.json` (deep merge, rules.md), `.claude/akg/config.yaml` (new overrides, `synced: <version>`).

Show each file's diff, then one numbered list of the files, guess: write all ("ok", "skip 2", "edit 1: …"). Write only what is approved. Always update `synced` in the `config.yaml` proposal, even if every change was declined (they are now overrides). If the user skips `config.yaml`, nothing is written there: `synced` stays behind, so say in one line that the reminder and these changes will come back.

End with at most 3 lines: what changed, install commands for any external-source plugin, and "commit `.claude/` and the changed `CLAUDE.md` files so teammates get them and don't see the reminder again".
