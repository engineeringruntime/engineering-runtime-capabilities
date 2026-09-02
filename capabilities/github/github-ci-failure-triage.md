# CI failure triage — why is the build red?

List recent failing Actions runs for a repository, then inspect one run
(including failed-job logs). Answers "why did the build fail?" without
fifteen browser tabs.

Both steps use curated `run list` / `run view` operations. There is no
step-output chaining: supply `run_id` explicitly (from the list step's
output / audit record, or from the Actions UI).

Rerun / cancel are deliberately omitted — those are write actions you
should invoke as a separate, intentional command after reading the
failure, not as part of the triage report itself.

Requires `RUNTIME_GITHUB_TOKEN` and `gh` installed (no `gh auth login`).

Run with:

```
runtime capability validate capabilities/github/github-ci-failure-triage.md

runtime capability execute capabilities/github/github-ci-failure-triage.md \
  --input repository=cli/cli \
  --input run_id=1234567890
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  run_id:
    description: Actions run id to inspect (from the list step output or the Actions UI)
    required: true

workflow:
  - provider: github
    args: [run, list, --repo, "${repository}", --status, failure, --limit, "10"]

  - provider: github
    args: [run, view, "${run_id}", --repo, "${repository}", --log-failed]
```
