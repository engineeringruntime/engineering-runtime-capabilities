# Re-run only the failed jobs of a workflow run

Retry the jobs that failed, leaving the ones that passed alone. The cheap
response to a flaky integration test, and the one that does not burn minutes
re-running a green matrix.

`github-ci-failure-triage` deliberately omits this: reading why a build failed
and acting on it are different decisions, and bundling them encourages the retry
before the reading. Run the triage first, then this — as a separate, intentional
command.

The endpoint takes no request body, which is why it is expressible here.

**A run with nothing to retry returns `403` and ends the capability.** Verified:
against a successful run GitHub answers `403 This workflow run cannot be
retried`, and step 2 stops. That is GitHub declining, not a fault — but it is
reported as a failed capability, so read step 1's `conclusion` before reacting
to the error.

Requires `RUNTIME_GITHUB_TOKEN` with write access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-actions-run-rerun-failed.md
runtime capability execute github/github-actions-run-rerun-failed \
  --input repository=acme/payments-api --input run_id=1234567890
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  run_id:
    description: Workflow run id, from github-ci-failure-triage or run list
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/actions/runs/${run_id}"]

  - provider: github
    args: [api, POST, "/repos/${repository}/actions/runs/${run_id}/rerun-failed-jobs"]
```
