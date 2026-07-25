# Dispatch an Actions workflow, then list the workflow catalog

Exercises `workflow run` and `workflow list` — the two `workflow`-family
operations no other checked-in capability in this folder touches yet
(`github-repo-health.md` and `github-daily-digest.md` both stop at `run
list`/`run view`-adjacent territory, never `workflow`).

Models a CI/CD trigger: kick a `workflow_dispatch`-enabled workflow (a
release, a deploy, a nightly job run on demand) and, in the same run,
confirm the workflow catalog `gh` sees for that repo — useful right after
adding a brand-new workflow file, to confirm Actions has picked it up
before trying to dispatch it for real.

Both operations resolve their repository from the working directory the
same way `gh workflow` commands always do (see
`github-pr-open-and-inspect.md` for the same prerequisite spelled out in
more detail) — run this from inside the target repository's clone, not
from `engineering-runtime`'s own checkout unless dispatching one of *its*
workflows is actually the intent.

Requires `RUNTIME_GITHUB_TOKEN` and `gh` installed (no `gh auth login`).
The target workflow must declare `on: workflow_dispatch` — `workflow run`
against a workflow that doesn't fails at GitHub, not at the runtime.

Run with:

```
runtime capability validate capabilities/github/github-workflow-dispatch-and-list.md

# from inside the target repo's clone:
runtime capability execute capabilities/github/github-workflow-dispatch-and-list.md \
  --input workflow=release.yaml --input ref=main
```

```runtime
version: v1

inputs:
  workflow:
    description: Workflow file name or ID to dispatch, e.g. release.yaml
    required: true
  ref:
    description: Branch or tag to run the workflow on
    required: true

workflow:
  - provider: github
    args: [workflow, run, "${workflow}", --ref, "${ref}"]

  - provider: github
    args: [workflow, list]
```

`workflow run` has no synchronous result to wait on — Actions queues the
run and returns immediately; nothing in this capability polls it to
completion. Use `github-repo-health.md`'s `run list` step (or `runtime
github run list --repo <repository>`) afterward, separately, to watch the
dispatched run progress.
