# Pull-request review readiness

Read the PR's merge/check summary, submitted reviews, and requested reviewers.
This capability does not approve, request, merge, or otherwise mutate the PR.

Requires `RUNTIME_GITHUB_TOKEN` with pull-request read access and `gh`.

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  number:
    description: Pull-request number
    required: true

workflow:
  - provider: github
    args: [pr, view, "${number}", --repo, "${repository}", --json, "number,title,state,isDraft,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup"]
  - provider: github
    args: [api, GET, "/repos/${repository}/pulls/${number}/reviews", "per_page=100"]
  - provider: github
    args: [api, GET, "/repos/${repository}/pulls/${number}/requested_reviewers"]
```
