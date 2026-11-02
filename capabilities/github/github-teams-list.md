# List teams in an organization

Single-step capability wrapping the fixed `GET /orgs/{org}/teams`
operation. The organization is an explicit input: GitHub has no native
context for Runtime to read, so nothing can supply it on your behalf.
Requires `ENGRT_GITHUB_TOKEN` to be exported.

Run with:

```
engrt capability validate github/github-teams-list.md
engrt capability execute github/github-teams-list.md --input organization=acme
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
