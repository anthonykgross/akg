# akg base questions

<!--
Format, for every layer (akg → team → project):
- `## Title` identifies a question. Same title in a higher layer replaces it; `skip` as its body removes it.
- `key:` is where the answer is stored in `.claude/akg/config.yaml`.
- Options are suggestions; rough free-text answers are fine.
- The `→` line tells Claude how the answer shapes the generated files.
A question whose key is already set by a lower layer is not asked; its value is shown instead.
-->

## Project context
key: workflow.context
What kind of project is this?
- Product in production (recommended)
- POC / prototype
- Library
- Internal tool
→ Sets the defaults of the next questions (a POC gets a lighter DoD, no TDD, light review).

## Definition of Done
key: workflow.dod
When is a change done? Propose a list based on the context and the detected commands, and let the user edit it.
- Tests pass, lint clean, docs updated (recommended for a product)
- Runs locally (POC)
→ Written in CLAUDE.md as the checklist Claude must meet before saying a task is finished.

## TDD
key: workflow.tdd
Write the tests before the code?
- Yes (recommended for a product or a library)
- No (recommended for a POC)
→ If yes, CLAUDE.md tells Claude to write a failing test first, then the code.

## Review level
key: workflow.review
How thorough should Claude's self-review be before handing over?
- Standard (recommended): re-read the diff, run tests and lint
- Light: run tests only
- Strict: standard + edge cases, security and performance pass
→ Written in CLAUDE.md as the review step of the workflow.
