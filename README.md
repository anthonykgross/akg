# akg

A Claude Code plugin that sets up Claude Code on a project from an optional **team config**, by asking a few questions about the project, then keeps it in sync with the team.

- **Scans first**: manifests, README, CI, tests and recent commits — stack, test/lint/build commands, monorepo sub-projects.
- **Shows what it understood**: purpose, key folders, architecture, integrations — and lets you add what matters ("edge functions are in `supabase/functions`", "we do DDD"). It lands in a `Project context` section of `CLAUDE.md` you own.
- **Asks every question, pre-filled**: project context, Definition of Done, TDD, review level by default; ticket tracker, deployment, commit convention… on demand; plus your team's. The known answer comes first — "(Team)", "(Project)" or "(Detected)" with its source — then the other options and "I don't know". One click to confirm, or correct and go further.
- **Generates**: `CLAUDE.md` (one per sub-project in a monorepo), `.claude/settings.json`, and the plugins to enable.
- **Never imposes**: every file is shown before it is written; every value, setting and plugin is a proposal. Local choices always win over the team's.

## Install

```
/plugin marketplace add anthonykgross/akg
/plugin install akg@akg
```

## Usage

| Command | When |
|---|---|
| `/akg:setup` | Once per project: link the team config (or none), confirm what was detected and understood, answer the pre-filled questions, review the generated files. |
| `/akg:pull` | When the team config changes: applies team updates, shows conflicts with your local overrides ("team says X, project says Y"), proposes new questions and plugins. |

When the project extends a team config, a new session shows one line when the team has a new version:

```
akg: team config updated — /akg:pull
```

It is shown once per team version, stays silent when offline, and never slows the session down (~2 s budget).

## Files

akg reads and writes the same files in the project and in the team repo:

```
.claude/akg/
  config.yaml      # values, settings, marketplaces
  questions.md     # questions asked by /akg:setup
  patterns/        # CLAUDE.md templates: common.md, backend.md, frontend.md
```

Three layers, the closest to the project wins: **akg defaults → team → project**.

### Project `config.yaml`

Only what differs from the team:

```yaml
extends: github:acme/claude-team   # team config; omit if none
synced: 4f2a9c1                    # team version at last pull (managed by akg)

workflow:
  tdd: false                       # POC
plugins:
  disabled: [code-review]
```

`extends` accepts `github:owner/repo`, a git URL, an HTTPS URL to a single `config.yaml`, or a local path. Private repos use your git credentials; private single files are not supported.

## Team repo

A team repo is a standard [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) plus `.claude/akg/`. Skills, hooks, agents and MCP servers are shipped as regular plugins — akg proposes them, Claude Code installs them.

```
claude-team/
  .claude-plugin/marketplace.json   # optional: your plugins
  plugins/…
  .claude/akg/
    config.yaml
    questions.md                    # optional
    patterns/                       # optional
```

A team can also be a single `config.yaml` (local or HTTPS), without plugins.

### `config.yaml`

```yaml
workflow:
  dod: [tests pass, lint clean, docs updated]
  tdd: true
  review: standard        # light | standard | strict

settings:                 # raw fragment of .claude/settings.json, deep-merged
  permissions:
    deny: ["Read(.env*)"]

marketplaces:             # extra marketplaces to draw plugins from
  - github:acme/frontend-plugins

questions: [workflow, tracker, deploy]   # which questions to ask, by key prefix
```

`questions` picks from akg's catalog and your own questions: `workflow` (context, DoD, TDD, review), `tracker` (ticket tracker), `deploy`, `git.commits`… Without it, akg asks `workflow` plus every question your team or project defines. The project list replaces the team's.

A value set here is still asked in `/akg:setup`, pre-selected as "(Team)": the developer confirms or overrides it.

### `questions.md`

Example of a team question:

```markdown
## Ticket tracker
key: tracker.tool
Do you use a ticket tracker?
- None (recommended)
- Jira
  → Ask its URL (key: tracker.url).
  → Check whether a Jira MCP server or the `jira` CLI is available; if not, suggest one.
  → CLAUDE.md: reference tickets as PROJ-123 in commits.
→ Add the tracker to the Project context.

## TDD
skip
```

- `## Title` identifies a question: the same title replaces the akg (or team) one, `skip` removes it, a new title adds it.
- `key` is where the answer is stored in `config.yaml`. Required: a question without `key` is ignored, with a one-line warning.
- `→` lines are instructions for Claude: under an option, applied when it is chosen; at the end, applied whatever the answer. They can ask a follow-up question, run a read-only check, or propose a `CLAUDE.md` line, a plugin or a setting — never install or change anything by themselves.

### Plugins

akg proposes a plugin from your marketplaces when:
- it has no `relevance` block (proposed on every project), or
- one of its [`relevance` signals](https://code.claude.com/docs/en/plugins/relevance) matches the project: `manifestDeps` (dependency in a manifest), `filesRead` (matching files exist), `cwd`, `cli` (command used in scripts/Makefile). `hosts` is ignored.

```json
{
  "name": "react-conventions",
  "source": "./plugins/react-conventions",
  "relevance": {
    "signals": {
      "manifestDeps": [{ "file": "[/\\\\]package\\.json$", "pattern": "\"react\"\\s*:" }]
    }
  }
}
```

## Development

```bash
claude plugin validate .                    # check manifests
fixtures/try.sh extends-local-team          # copy fixtures to a temp dir, print the command to run
```

`fixtures/` holds sandbox projects (no team, extending a local team repo, monorepo) to replay each flow by hand; see [fixtures/README.md](fixtures/README.md).
