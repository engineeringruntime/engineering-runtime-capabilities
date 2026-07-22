# List issues for a specific repository

Uses the generic `github.request` pass-through to query a single
repo's issues, filtered by `state`. `GET` requests turn every
`key=value` arg into a query parameter. Requires `RUNTIME_GITHUB_TOKEN`
to be exported.

Run with:

```
runtime capability validate github/github-request-list-repo-issues.md
runtime capability execute github/github-request-list-repo-issues.md \
  --input owner=octocat --input repo=hello-world --input state=open
```

```runtime
version: v1

inputs:
  owner:
    description: Repository owner (user or organization)
    required: true
  repo:
    description: Repository name
    required: true
  state:
    description: "Issue state to filter by: open, closed, or all"
    required: true

workflow:
  - command: github.request
    args: [GET, "/repos/${owner}/${repo}/issues", "state=${state}"]
```
