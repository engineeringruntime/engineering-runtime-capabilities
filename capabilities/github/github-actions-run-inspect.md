# List recent Actions runs, then inspect one by ID

Exercises `run list` and `run view` together. `run list` alone is already
covered by `github-repo-health.md`; `run view` — drilling into one
specific run's status, conclusion, and job breakdown — isn't demonstrated
anywhere yet.

Both steps use the required explicit `repository` input, not the current
working directory. Requires `ENGRT_GITHUB_TOKEN` and `gh` installed
(no `gh auth login`).

Run with:

```
engrt capability validate capabilities/github/github-actions-run-inspect.md

engrt capability execute capabilities/github/github-actions-run-inspect.md \
  --input repository=acme/service --input run_id=123456789
```

```runtime
version: v1

inputs:
  repository:
    description: Explicit OWNER/REPO whose Actions runs are inspected
    required: true
  run_id:
    description: Run ID to inspect, e.g. one seen in the run list step's own output on a previous invocation
    required: true

workflow:
  - provider: github
    args: [run, list, --repo, "${repository}", --limit, "10"]

  - provider: github
    args: [run, view, "${run_id}", --repo, "${repository}", --json, "status,conclusion,jobs"]
```

`run_id` is a required input, not captured from the first step. If it is
unknown, separately run `engrt github run list --repo OWNER/REPO` when
authorized, then select a real returned ID. Never supply a guessed placeholder
just to get past input validation. Neither step waits for an active run to finish.
