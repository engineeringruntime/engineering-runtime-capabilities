# Runners and cache usage for a repository

Self-hosted runners registered to the repository, and how much Actions cache it
is consuming. Two questions that only get asked when something is wrong — a job
queued forever against an offline runner, or a cache quietly at its limit.

A repository using only GitHub-hosted runners returns an empty runner list.
That is the expected answer, not an error.

Read-only. Removing a runner is a `DELETE`, which default policy denies.

Requires `RUNTIME_GITHUB_TOKEN` with admin read on the repository.

Run with:

```
runtime capability validate capabilities/github/github-actions-runners-and-cache.md
runtime capability execute github/github-actions-runners-and-cache \
  --input repository=engineeringruntime/engineering-runtime-ci
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/actions/runners"]

  - provider: github
    args: [api, GET, "/repos/${repository}/actions/cache/usage"]
```
