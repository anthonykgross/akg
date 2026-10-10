# Team questions (fixture)

## Review level
key: workflow.review
How thorough should Claude's self-review be? (team override)
- Standard (recommended): re-read the diff, run tests and lint
- Strict: standard, plus edge cases and security
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
→ If deployed: add the deployment target to the Project context.
