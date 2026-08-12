# List repositories for any GitHub organization

Uses the generic `github.request` pass-through instead of
`repo list` with an org argument so it can target *any* org by name —
both take the organization explicitly — Runtime has no context to read one from. Requires
`RUNTIME_GITHUB_TOKEN` to be exported.

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
