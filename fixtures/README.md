# Fixtures

Sandbox projects to replay each user flow by hand.

| Fixture | Stack | Team config | Checks |
|---|---|---|---|
| `no-team/` | Node CLI | none | Setup works without a team; 10 default questions (5 `workflow` + dependencies, local environment, architecture, secrets, ticket tracker; Claude autonomy as checkboxes; no Command environment, no Docker); answers "(Detected)" from the scan; no plugin proposed |
| `extends-local-team/` | React app | `../team` | `../team` offered as team config; team values pre-selected "(Team)"; team `questions: [workflow, tracker, deploy]` → 7 questions (team Review and Deployment override akg's; Ticket tracker from the akg catalog; answering Jira asks its URL, project key and hosting in plain text); `code-review` + `react-conventions` proposed |
| `monorepo/` | Vue + Go + Terraform | none (or `../team`) | Sub-project detection and per-folder `CLAUDE.md` |
| `source/` | empty | — | `/akg:source-init`: stacks asked; questions phrased for the team, no "(Detected)", `per-project` ones and Command environment skipped; optional prefixes asked; Installed / Official tabs; "From an existing project" with `../monorepo`; `config.yaml`, `marketplace.json` (named `source`), `team.md` skeleton, `README.md`, `git init` proposed |
| `team/` | — | — | Local team repo: marketplace with 3 plugins + `.claude/akg/` (with `team.md`: `/akg:team` from `extends-local-team/` shows it; setup ends with a line pointing to it) |

## Usage

```bash
fixtures/try.sh extends-local-team
```

Copies all fixtures to a temp dir (never test in place: files would be written into this repo and its `CLAUDE.md` would leak into the session), turns `team/` into a git repo, and prints the `claude --plugin-dir` command to run.

To test `/akg:pull`: commit a change in the temp `team/` copy, start a new session (reminder expected), then run `/akg:pull`.
