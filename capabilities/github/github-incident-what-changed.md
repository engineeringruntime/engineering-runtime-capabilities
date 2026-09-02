# Incident forensics — what changed since T

During an incident: commits since a timestamp, recently merged pull
requests, recent deployments, and recent pushes to `main` via Actions.
The "what changed in the last N hours" pack that pays for itself the
first time it is used at 3am.

`since` must be an ISO-8601 timestamp GitHub accepts on the Commits API
(e.g. `2026-07-24T00:00:00Z`). There is no step that "rolls back" —
default policy and this capability stay read-only.

Requires `RUNTIME_GITHUB_TOKEN` and `gh` installed (for `pr list` /
`run list`).

Run with:

```
runtime capability validate capabilities/github/github-incident-what-changed.md

runtime capability execute capabilities/github/github-incident-what-changed.md \
  --input repository=acme/payments-api \
  --input since=2026-07-24T00:00:00Z \
  --input environment=production
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  since:
    description: ISO-8601 timestamp — commits at or after this instant
    required: true
  environment:
    description: Deployment environment to list (e.g. production)
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/commits", "since=${since}", "per_page=100"]

  - provider: github
    args: [pr, list, --repo, "${repository}", --state, merged, --limit, "20", --json, "number,title,mergedAt,author"]

  - provider: github
    args: [api, GET, "/repos/${repository}/deployments", "environment=${environment}", "per_page=10"]

  - provider: github
    args: [run, list, --repo, "${repository}", --branch, main, --event, push, --limit, "10"]
```
