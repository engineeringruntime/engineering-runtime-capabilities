# List recent Actions runs, then inspect one by ID

Exercises `run list` and `run view` together. `run list` alone is already
covered by `github-repo-health.md`; `run view` — drilling into one
specific run's status, conclusion, and job breakdown — isn't demonstrated
anywhere yet.

Same working-directory-resolution prerequisite as every other `gh`-backed
operation in this folder (`pr create`, `workflow run`, `pr list`): run this
from inside the target repository's clone. Requires `RUNTIME_GITHUB_TOKEN`
and `gh` installed (no `gh auth login`).

Run with:

```
runtime capability validate capabilities/github/github-actions-run-inspect.md

# from inside the target repo's clone:
runtime capability execute capabilities/github/github-actions-run-inspect.md \
  --input run_id=123456789
```

```runtime
version: v1

inputs:
  run_id:
    description: Run ID to inspect, e.g. one seen in the run list step's own output on a previous invocation
    required: true

workflow:
  - provider: github
    args: [run, list, --limit, "10"]

  - provider: github
    args: [run, view, "${run_id}", --json, "status,conclusion,jobs"]
```

Like `github-pr-open-and-inspect.md`, `run_id` is a required input rather
than something this capability discovers on its own — there is no
step-output chaining, so the natural way to use this is: run it once with
any placeholder `run_id` to see the `run list` step's real output, note a
real run ID from that, then re-run with `run_id` set to inspect it.
