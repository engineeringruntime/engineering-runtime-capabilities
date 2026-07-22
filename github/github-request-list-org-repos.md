# List repositories for any GitHub organization

Uses the generic `github.request` pass-through instead of
`github.repositories.list_for_org` so it can target *any* org by name —
not just the one bound to the active Runtime Context. Requires
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
  - command: github.request
    args: [GET, "/orgs/${organization}/repos"]
```
