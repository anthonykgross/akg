<!--
akg base template for the root CLAUDE.md.
Claude adapts it to the answers (`workflow.*` and other keys) and to the detected stack:
drop sections that don't apply, fill in real commands, never invent commands the project doesn't declare.
-->

# {{project name}}

{{one-line description of the project, from the README or the manifest}}

## Commands

- Test: `{{test command}}`
- Lint: `{{lint command}}`
- Build: `{{build command}}`

## Workflow

1. {{if workflow.tdd: write a failing test first}}
2. Implement the change.
3. Review: {{workflow.review}}.
4. Done when: {{workflow.dod as a checklist}}

## Conventions

- Match the style of the surrounding code.
- Keep changes focused on the task.
