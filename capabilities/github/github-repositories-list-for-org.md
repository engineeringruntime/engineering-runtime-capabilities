# List repositories for an organization

Single-step capability wrapping the fixed `GET /orgs/{org}/repos`
operation. The organization is an explicit input: GitHub has no native
context for Runtime to read, so nothing can supply it on your behalf.
Omitting it from `runtime github repo list` lists the authenticated
user's own repositories instead, which is a different question.
Requires `RUNTIME_GITHUB_TOKEN` to be exported.

Run with:

```
runtime capability validate github/github-repositories-list-for-org.md
runtime capability execute github/github-repositories-list-for-org.md --input organization=acme
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization whose repositories to list
    required: true

workflow:
  - provider: github
    args: [repo, list, "${organization}"]
```
