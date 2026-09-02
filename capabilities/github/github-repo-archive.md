# Archive a repository

Make a repository read-only: no pushes, no new issues or pull requests, and a
banner saying so. The honest end state for a service that has been
decommissioned but whose history is still worth keeping.

**Archiving is reversible, deletion is not — and this capability cannot delete.**
Default policy denies `api DELETE`, so the destructive neighbour of this
operation is closed off rather than merely undocumented. To unarchive, run the
same capability with `archived=false`.

Read the repository first with `github-repo-settings-get`: archiving a repo with
open pull requests freezes them in place rather than closing them.

Requires `RUNTIME_GITHUB_TOKEN` with admin access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-archive.md
runtime capability execute github/github-repo-archive \
  --input repository=acme/legacy-billing --input archived=true
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  archived:
    description: true to archive, false to unarchive
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}"]

  - provider: github
    args: [api, PATCH, "/repos/${repository}", "archived=${archived}"]
```
