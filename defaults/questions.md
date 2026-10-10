# akg base questions

<!--
Format, for every layer (akg → team → project):
- `## Title` identifies a question. Same title in a higher layer replaces it; `skip` as its body removes it.
- `key:` is where the answer is stored in `.claude/akg/config.yaml`.
- Options are suggestions; rough free-text answers are fine.
- `→` lines are free-text instructions for Claude:
  - under an option: applied only when that option is chosen;
  - at the end of the question: applied whatever the answer.
  They can ask a follow-up question (with its own key), check something read-only (a command, an MCP server, a file),
  propose something (a line in CLAUDE.md, a plugin, a setting). They never install or modify anything by themselves.
A question whose key is already set by a lower layer is not asked; its value is shown instead.
-->

## Project context
key: workflow.context
What kind of project is this?
- Product in production (recommended)
  → Defaults for the next questions: full DoD, TDD, standard review.
- POC / prototype
  → Defaults for the next questions: DoD "runs locally", no TDD, light review.
- Library
  → Defaults: TDD, strict review. CLAUDE.md: public API changes must stay backward compatible and be documented.
- Internal tool
  → Defaults: tests on the core logic only, standard review.

## Definition of Done
key: workflow.dod
When is a change done? Propose 2–3 lists built from the context and the detected commands.
→ CLAUDE.md: the checklist Claude must meet before saying a task is finished, with the real commands.

## TDD
key: workflow.tdd
Write the tests before the code?
- Yes (recommended for a product or a library)
  → CLAUDE.md: write a failing test first, then the code, then refactor.
- No (recommended for a POC)
  → CLAUDE.md: add or update tests for the changed behaviour before finishing.

## Review level
key: workflow.review
How thorough should Claude's self-review be before handing over?
- Standard (recommended)
  → CLAUDE.md: re-read the diff, run tests and lint before handing over.
- Light
  → CLAUDE.md: run the tests before handing over.
- Strict
  → CLAUDE.md: standard review, plus a pass on edge cases, security and performance.

## Ticket tracker
key: tracker.tool
Do you use a ticket tracker?
- None (recommended)
- Jira
  → Ask its URL and the project key (keys: tracker.url, tracker.project).
  → Check whether an Atlassian/Jira MCP server is configured (`claude mcp list`) or a `jira` CLI is on the PATH; if neither, suggest one.
  → CLAUDE.md: reference tickets as <PROJECT>-123 in branch names and commit messages.
- Linear
  → Ask the team key (key: tracker.project).
  → Check whether a Linear MCP server is configured (`claude mcp list`); if not, suggest it.
  → CLAUDE.md: reference issues by their identifier in branch names and commit messages.
- GitHub Issues
  → Check whether the `gh` CLI is on the PATH and authenticated (`gh auth status`); if not, suggest it.
  → CLAUDE.md: reference issues as #123 in commit messages.
→ Add the tracker (and URL if any) to the Project context.
