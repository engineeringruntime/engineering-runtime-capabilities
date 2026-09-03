# List repositories for any GitHub organization

Uses the generic `github.request` pass-through rather than the curated
`repo list <org>` operation, as an escape-hatch demonstration. Prefer the
curated operation for real work — both take the organization as an
explicit input. Requires `RUNTIME_GITHUB_TOKEN` to be exported.

Run with:

```
runtime capability validate github/github-request-list-org-repos.md
runtime capability execute github/github-request-list-org-repos.md \
  --input organization=octocat
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization to inspect
    required: true

workflow:
  - provider: github
    args: [api, GET, "/orgs/${organization}/repos"]
```
