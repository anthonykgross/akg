# Evals

Automated replay of akg's flows with `claude plugin eval`, on the `fixtures/` projects.

```bash
evals/run.sh                                  # whole suite, 3 runs per case
evals/run.sh --case 'setup-*' --runs 1        # a subset, once
`evals/run.sh --case pull-team-change --keep-temp`   # keep the workspace and trace
```

Needs the Bash sandbox: on Linux, `bubblewrap` and `socat`; on Ubuntu, also lift AppArmor's user-namespace restriction (`sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`, until reboot, or bubblewrap's AppArmor profile: https://code.claude.com/docs/en/sandboxing). A full run with `--runs 1` costs about $3.

| Case | Checks |
|---|---|
| `setup-first-turn-no-team` | akg files read with Read in the first turn, no shell reads, only the Team config question, guess none |
| `setup-first-turn-team` | `fetch.sh ../team` and `claude mcp list` run before the first question, guess `../team` |
| `setup-full-no-team` | Generated files: settings (test command in both forms, `.env` deny, install `ask`, no plugins), config without `extends`, `.gitignore` |
| `setup-full-team` | `extends`/`synced`, team values not copied, team plugins enabled by relevance, team template in `CLAUDE.md`, missing team tools listed and never run |
| `setup-full-monorepo` | One `CLAUDE.md` per sub-project, none for `infra/`, `terraform apply/destroy` asked in both forms |
| `pull-team-change` | Team v2 vs v1: conflict kept local, DoD and `deny` applied, `## Project context` untouched, `team.md` diff, new tool listed |
| `team-show` | `team.md` shown verbatim, nothing run or written |
| `source-init-full` | Source files written, no `extends` or `per-project` answers, `team.md` skeleton, no `questions.md` |

How it works:
- **One turn.** Evals have no simulated user, so the full cases tell Claude to take each guess as the answer and go to the end. They check the guesses and the generated files, not the conversation; the first-turn cases check what happens before the first question.
- **Fixtures.** Each case's `scaffold.sh` calls `lib/fixture.sh`, which copies a fixture into the workspace and, with `--team`, the team repo to `../team` with fixed commit dates (stable SHAs). `--setup-done` adds a project already set up against team v1 (`lib/setup-done/`) and commits team v2 (`lib/team-v2/`).
- **Run environment**: a temporary HOME with a read-only cache, and no `claude` (nor nvm's `npm`) on the PATH, so MCP and plugin checks report "not checked". The scripts fall back to a temp dir when the cache is read-only.
- **`.claude/` writes are blocked in evals**, so graders on `.claude/settings.json` and `.claude/akg/config.yaml` match the `Write`/`Edit` call in the trace (`content` or `new_string` of that file), not the file on disk.
