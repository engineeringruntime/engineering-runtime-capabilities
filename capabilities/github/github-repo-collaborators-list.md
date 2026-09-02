# Who has access to this repository

Direct collaborators, the teams granted access, and the invitations still
pending. The three lists that together answer "who can push to this?" — a
question the repository UI splits across two settings pages.

Read-only, and deliberately so: this capability shows access, it does not grant
or revoke it. Revocation is a `DELETE`, which default policy denies, so the
destructive half cannot be reached from here even by mistake.

Narrower than `github-access-review`, which covers a whole organisation. Use
this one when the question is about a single repository.

Requires `RUNTIME_GITHUB_TOKEN` with **push access** to the repository. Read
access is not enough: GitHub returns `403 Must have push access to view
repository collaborators`, and the capability stops there. Verified against
`cli/cli` (403) and against an owned repository (all three steps complete).

Run with:

```
runtime capability validate capabilities/github/github-repo-collaborators-list.md
runtime capability execute github/github-repo-collaborators-list --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/collaborators", "per_page=100"]

  - provider: github
    args: [api, GET, "/repos/${repository}/teams", "per_page=100"]

  - provider: github
    args: [api, GET, "/repos/${repository}/invitations"]
```
