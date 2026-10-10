<!--
akg base template for a backend sub-project CLAUDE.md.
Claude adapts it to the answers and to the detected stack.
-->

# {{sub-project name}} (backend)

## Commands

- Test: `{{test command}}`
- Run: `{{run command}}`

## Conventions

- Validate input at the boundaries (API handlers, CLI, message consumers).
- Handle errors explicitly; never swallow them.
- Database schema changes go through migrations.
