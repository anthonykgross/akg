# Fixtures

Sandbox projects to replay each user flow by hand.

| Fixture | Stack | Team config | Checks |
|---|---|---|---|
| `no-team/` | Node CLI | none | Setup works without a team; 7 default questions (5 `workflow` + architecture, secrets; Claude autonomy as checkboxes); answers "(Detected)" from the scan; no plugin proposed |
| `extends-local-team/` | React app | `../team` | `../team` offered as team config; team values pre-selected "(Team)"; team `questions: [workflow, tracker, deploy]` → 7 questions (team Review and Deployment override akg's; Ticket tracker from the akg catalog; answering Jira asks its URL and project key in plain text); `code-review` + `react-conventions` proposed |
| `monorepo/` | Vue + Go + Terraform | none (or `../team`) | Sub-project detection and per-folder `CLAUDE.md` |
| `team/` | — | — | Local team repo: marketplace with 3 plugins + `.claude/akg/` |

## Usage

```bash
fixtures/try.sh extends-local-team
```

Copies all fixtures to a temp dir (never test in place: files would be written into this repo and its `CLAUDE.md` would leak into the session), turns `team/` into a git repo, and prints the `claude --plugin-dir` command to run.

To test `/akg:pull`: commit a change in the temp `team/` copy, start a new session (reminder expected), then run `/akg:pull`.
