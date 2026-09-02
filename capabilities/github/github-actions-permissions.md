# What Actions is allowed to do in this repository

Read the three settings that bound every workflow run: which actions may be
used, what permissions the default `GITHUB_TOKEN` carries, and whether workflows
may approve pull requests.

This is the highest-leverage read in the Actions surface. A repository that
allows any action from anywhere and hands workflows a write-scoped default token
has, in effect, granted push access to every dependency in every workflow file.

Read-only. Changing these takes a nested body (`allowed_actions_config`), which
the `api` operation cannot express — see the note in `github-repo-settings-get`.

**`/actions/permissions/access` is deliberately not read here.** It applies only
to internal and private repositories and answers `422 Access policy only applies
to internal and private repositories` on a public one, which aborts the run. An
earlier draft included it and failed against every public repository.

Requires `RUNTIME_GITHUB_TOKEN` with admin read on the repository.

Run with:

```
runtime capability validate capabilities/github/github-actions-permissions.md
runtime capability execute github/github-actions-permissions \
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
    args: [api, GET, "/repos/${repository}/actions/permissions"]

  - provider: github
    args: [api, GET, "/repos/${repository}/actions/permissions/workflow"]
```
