# List issues across an organization

Single-step capability wrapping the fixed `GET /orgs/{org}/issues`
operation. The organization is an explicit input: GitHub has no native
context for Runtime to read, so nothing can supply it on your behalf.
Requires `ENGRT_GITHUB_TOKEN` to be exported.

Run with:

```
engrt capability validate github/github-issues-list-for-org.md
engrt capability execute github/github-issues-list-for-org.md --input organization=acme
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization whose issues to list
    required: true

workflow:
  - provider: github
    args: [issue, list, "${organization}"]
```
