# List teams in an organization

Single-step capability wrapping the fixed `GET /orgs/{org}/teams`
operation. The organization is an explicit input: GitHub has no native
context for Runtime to read, so nothing can supply it on your behalf.
Requires `RUNTIME_GITHUB_TOKEN` to be exported.

Run with:

```
runtime capability validate github/github-teams-list.md
runtime capability execute github/github-teams-list.md --input organization=acme
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization whose teams to list
    required: true

workflow:
  - provider: github
    args: [team, list, "${organization}"]
```
