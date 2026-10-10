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
- Lambda
- None
→ Add the deployment target and its constraints to CLAUDE.md.
