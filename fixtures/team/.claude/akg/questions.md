# Team questions (fixture)

## Review level
key: workflow.review
How thorough should Claude's self-review be? (team override)
- Strict (recommended): diff, tests, lint, edge cases, security
- Standard
→ Written in CLAUDE.md as the review step of the workflow.

## Deployment
key: deploy.target
Where is this project deployed?
- Kubernetes (recommended)
  → Ask the namespace (key: deploy.namespace): offer a detected value (k8s manifests) as option, otherwise ask in one plain-text message.
  → Check whether `kubectl` is on the PATH; if not, mention it.
- Lambda
  → CLAUDE.md: keep handlers small, cold start matters.
- None
→ Add the deployment target to the Project context.

## Ticket tracker
key: tracker.tool
Do you use a ticket tracker?
- None (recommended)
- Jira
  → Ask its URL and the project key (keys: tracker.url, tracker.project): offer detected values as options, otherwise ask in one plain-text message.
  → Check whether an Atlassian/Jira MCP server is configured (`claude mcp list`) or a `jira` CLI is on the PATH; if neither, suggest one.
  → CLAUDE.md: reference tickets as <PROJECT>-123 in branch names and commit messages.
- Linear
  → Ask the team key (key: tracker.project): offer a detected value as option, otherwise ask in one plain-text message.
  → Check whether a Linear MCP server is configured (`claude mcp list`); if not, suggest it.
  → CLAUDE.md: reference issues by their identifier in branch names and commit messages.
- GitHub Issues
  → Check whether the `gh` CLI is on the PATH and authenticated (`gh auth status`); if not, suggest it.
  → CLAUDE.md: reference issues as #123 in commit messages.
→ Add the tracker (and URL if any) to the Project context.
