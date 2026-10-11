# Acme — Claude Code

## Getting started

1. Run `/akg:setup` in your project and give `../team` as the team config.
2. Ask in #dev-tools for access to the Jira MCP server.

## Tools to install

- **gh** — GitHub CLI, used to read issues and open PRs: `brew install gh && gh auth login`
- **Atlassian MCP** — read Jira tickets from Claude: `claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/sse`
- **terraform-helpers** skill needs `tflint`: `brew install tflint`

## Rules

- Never paste production data into a prompt.
- Claude-written PRs are reviewed like any other.
