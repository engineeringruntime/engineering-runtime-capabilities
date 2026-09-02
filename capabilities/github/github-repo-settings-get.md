# Repository settings — the configuration that governs a repo

Read the settings that decide how a repository behaves: its metadata and merge
policy, its topics, and its branches. One audited pass instead of three tabs in
the Settings UI.

No curated operation covers these fields, so every step uses the `api` escape
hatch. Read-only — `api DELETE` is denied by default policy, and nothing here
writes.

This is the companion read for `github-repo-merge-policy-enforce` and
`github-repo-features-enforce`: run this first to see what a repository has,
then enforce only what you mean to change.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-settings-get.md
runtime capability execute github/github-repo-settings-get --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}"]

  - provider: github
    args: [api, GET, "/repos/${repository}/topics"]

  - provider: github
    args: [api, GET, "/repos/${repository}/branches"]
```
